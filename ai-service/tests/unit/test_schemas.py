import pytest
from pydantic import ValidationError

from app.schemas.room import RoomDimensions, UserPreferences


def test_room_dimensions_requires_cm() -> None:
    assert RoomDimensions(unit="cm").unit == "cm"
    with pytest.raises(ValidationError):
        RoomDimensions(unit="m")


def test_preferences_defaults() -> None:
    prefs = UserPreferences()
    assert prefs.mode == "auto_design"
    assert prefs.colors == []

