import pytest
from pydantic import ValidationError

from app.schemas.design_job import ProductCard
from app.schemas.room import RoomDimensions, UserPreferences


def test_room_dimensions_requires_cm() -> None:
    assert RoomDimensions(unit="cm").unit == "cm"
    with pytest.raises(ValidationError):
        RoomDimensions(unit="m")


def test_preferences_defaults() -> None:
    prefs = UserPreferences()
    assert prefs.mode == "auto_design"
    assert prefs.colors == []



def test_product_card_includes_frontend_mapping_fields() -> None:
    card = ProductCard(
        product_id="00000000-0000-0000-0000-000000000001",
        external_id="sku-1",
        name="Oak Coffee Table",
        category="coffee_table",
        role="coffee_table",
        score=0.91,
    )

    assert card.role == "coffee_table"
    assert card.score == 0.91
