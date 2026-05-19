from sqlalchemy.orm import Session

from app.schemas.ai_outputs import RoomAnalysisResult
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def analyze_room_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "analyze_room")
        result = RoomAnalysisResult(
            room_type="living_room",
            detected_styles=[state.get("user_preferences", {}).get("design_style") or "unknown"],
            color_palette=state.get("user_preferences", {}).get("colors") or [],
            temperature=state.get("user_preferences", {}).get("temperature"),
            lighting="unknown",
            existing_furniture=[],
            available_placement_zones=[
                {"label": "central_floor", "polygon": [[260, 430], [1020, 430], [1120, 700], [160, 700]]}
            ],
            constraints={},
            confidence=0.65,
        )
        return {"room_analysis": result.model_dump()}

    return node

