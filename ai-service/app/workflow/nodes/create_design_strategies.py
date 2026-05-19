import json

import structlog
from sqlalchemy.orm import Session

from app.ai.vertex_client import VertexAIClient, load_prompt
from app.core.config import get_settings
from app.schemas.ai_outputs import DesignStrategy
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState

logger = structlog.get_logger(__name__)

SUPPORTED_ROLES = {
    "dining_table", "dining_chair", "wardrobe", "dresser", "nightstand",
    "console_table", "mirror", "bed", "coffee_table", "sofa", "armchair",
    "bookshelf", "tv_unit", "floor_lamp", "carpet", "side_table",
    "desk", "storage_unit", "office_chair", "curtain",
}

# Default roles by room type when no user preferences or AI output is available.
_ROOM_TYPE_ROLES: dict[str, list[str]] = {
    "bedroom": ["bed", "nightstand", "wardrobe", "dresser", "floor_lamp"],
    "living_room": ["sofa", "coffee_table", "tv_unit", "armchair", "floor_lamp"],
    "dining_room": ["dining_table", "dining_chair", "console_table", "carpet"],
    "kitchen": ["dining_table", "dining_chair", "storage_unit"],
    "office": ["desk", "office_chair", "bookshelf", "floor_lamp"],
    "studio": ["sofa", "desk", "bookshelf", "floor_lamp", "carpet"],
}
ROOM_DEFAULT_ROLES = _ROOM_TYPE_ROLES  # alias for compatibility
DEFAULT_ROLES = ["coffee_table", "floor_lamp", "carpet", "bookshelf"]

_STYLE_PALETTE = [
    "modern", "scandinavian", "minimalist", "industrial",
    "traditional", "bohemian", "mid_century", "luxury",
]


def _roles_from_room_analysis(room_analysis: dict) -> list[str]:
    """Extract furniture category labels detected in the room image."""
    roles = []
    for item in room_analysis.get("existing_furniture", []):
        label = item.get("label", "")
        if label and label not in roles:
            roles.append(label)
    return roles


def _default_roles_for_room(room_type: str, detected_roles: list[str]) -> list[str]:
    """Combine room-type defaults with detected furniture for smart fallback."""
    base = list(_ROOM_TYPE_ROLES.get(room_type, DEFAULT_ROLES))
    for role in detected_roles:
        if role not in base:
            base.append(role)
    return base[:6]  # cap to avoid overly long lists


def _room_type(room_analysis: dict) -> str:
    architectural_context = room_analysis.get("architectural_context") or {}
    return architectural_context.get("room_type") or room_analysis.get("room_type") or "living_room"


def _strategy_room_analysis(room_analysis: dict, ignore_existing: bool) -> dict:
    if not ignore_existing:
        return room_analysis
    return {
        "room_type": _room_type(room_analysis),
        "architectural_context": room_analysis.get("architectural_context") or {},
        "available_placement_zones": room_analysis.get("available_placement_zones") or [],
        "constraints": room_analysis.get("constraints") or {},
        "lighting": room_analysis.get("lighting"),
        "color_palette": room_analysis.get("color_palette") or [],
        "detected_styles": room_analysis.get("detected_styles") or [],
        "existing_objects_ignored": True,
    }


def _sanitize_strategy(
    strategy: DesignStrategy,
    room_analysis: dict,
    prefs: dict,
) -> DesignStrategy:
    roles = [role for role in strategy.furniture_roles if role in SUPPORTED_ROLES]
    if not roles:
        roles = ROOM_DEFAULT_ROLES.get(_room_type(room_analysis), DEFAULT_ROLES)
    return DesignStrategy(
        design_index=strategy.design_index,
        title=strategy.title,
        style=strategy.style or prefs.get("design_style") or "balanced",
        furniture_roles=roles,
        notes=strategy.notes,
    )


def create_design_strategies_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "create_design_strategies")
        settings = get_settings()
        prefs = state.get("user_preferences", {})
        room_analysis = state.get("room_analysis", {})
        count = int(state.get("requested_design_count") or 3)
        room_type = _room_type(room_analysis)
        detected_roles = _roles_from_room_analysis(room_analysis)

        if settings.mock_ai or not settings.vertex_project_id:
            logger.info("create_design_strategies_mock")
            return _mock_strategies(prefs, count, room_type, detected_roles)

        # Real AI strategy generation
        logger.info("create_design_strategies_vertex_ai")
        client = VertexAIClient(settings)
        prompt_template = load_prompt("design_strategy.md")

        prompt_room_analysis = _strategy_room_analysis(
            room_analysis,
            settings.ignore_existing_furniture,
        )
        prompt = (
            f"{prompt_template}\n\n"
            f"Room analysis:\n{json.dumps(prompt_room_analysis, indent=2)}\n\n"
            f"User preferences:\n{json.dumps(prefs, indent=2)}\n\n"
            f"Ignore existing furniture: {settings.ignore_existing_furniture}\n\n"
            f"Requested design count: {count}\n"
        )

        try:
            from app.utils.json_utils import extract_json_object

            parts = [{"text": prompt}]
            text = client._stream_generate(
                parts, temperature=0.4, response_mime_type="application/json", model_tier="flash"
            )
            parsed = extract_json_object(text)
            if isinstance(parsed, list):
                strategies = [DesignStrategy.model_validate(s) for s in parsed]
            else:
                strategy_items = parsed.get("strategies", parsed.get("designs", [parsed]))
                strategies = [DesignStrategy.model_validate(s) for s in strategy_items]
        except Exception as exc:
            logger.warning("design_strategy_ai_failed_fallback", error=str(exc))
            return _mock_strategies(prefs, count, room_type, detected_roles)

        # Ensure we have exactly the requested count — fill with smart mocks if AI returned fewer.
        if len(strategies) < count:
            logger.info(
                "design_strategy_fill_missing",
                ai_returned=len(strategies),
                requested=count,
            )
            fill = _make_mock_strategies(
                prefs, count - len(strategies), room_type, detected_roles,
                start_index=len(strategies) + 1,
            )
            strategies.extend(fill)

        sanitized = [_sanitize_strategy(s, room_analysis, prefs) for s in strategies[:count]]
        return {"design_strategies": [s.model_dump() for s in sanitized]}

    return node


def _mock_strategies(prefs: dict, count: int, room_type: str, detected_roles: list[str]) -> dict:
    strategies = _make_mock_strategies(prefs, count, room_type, detected_roles, start_index=1)
    return {"design_strategies": [s.model_dump() for s in strategies]}


def _make_mock_strategies(
    prefs: dict,
    count: int,
    room_type: str,
    detected_roles: list[str],
    start_index: int = 1,
) -> list[DesignStrategy]:
    """Generate deterministic mock strategies using room type and detected furniture."""
    base_roles = _default_roles_for_room(room_type, detected_roles)
    user_roles = [r for r in (prefs.get("requested_furniture_types") or []) if r in SUPPORTED_ROLES]
    user_style = prefs.get("design_style")

    strategies = []
    for i in range(count):
        index = start_index + i
        # Rotate through style palette for diversity.
        style = user_style if user_style else _STYLE_PALETTE[i % len(_STYLE_PALETTE)]

        # First strategy uses detected/user roles; subsequent ones vary.
        if i == 0:
            roles = user_roles if user_roles else base_roles
        elif i == 1 and detected_roles:
            # Second strategy focuses on replacement of detected furniture.
            roles = detected_roles[:4] + [r for r in base_roles if r not in detected_roles][:2]
        else:
            # Subsequent strategies pick a different subset.
            offset = i * 2
            roles = (base_roles[offset:] + base_roles[:offset])[:4]

        # Sanitize roles against supported catalog.
        roles = [r for r in roles if r in SUPPORTED_ROLES] or list(base_roles[:3])

        strategy = DesignStrategy(
            design_index=index,
            title=f"{style.replace('_', ' ').title()} Design {index}",
            style=style,
            furniture_roles=roles or list(DEFAULT_ROLES),
            notes=prefs.get("extra_preferences") or f"Auto-generated {style} concept for {room_type}.",
        )
        strategies.append(strategy)

    return strategies
