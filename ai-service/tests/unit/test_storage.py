from pathlib import Path

from app.core.config import Settings
from app.storage.local_storage import LocalImageStorage


def test_storage_resolves_root_relative_paths(tmp_path: Path) -> None:
    settings = Settings(
        local_image_root=tmp_path / "images",
        room_upload_dir=tmp_path / "images" / "rooms",
        product_image_dir=tmp_path / "images" / "products",
        generated_image_dir=tmp_path / "images" / "generated",
    )
    storage = LocalImageStorage(settings)

    assert storage.resolve_room_image("rooms/2026/05/input.jpeg") == (
        tmp_path / "images" / "rooms" / "2026" / "05" / "input.jpeg"
    ).resolve()
    assert storage.resolve_product_image("products/source/item/main.jpg") == (
        tmp_path / "images" / "products" / "source" / "item" / "main.jpg"
    ).resolve()


def test_storage_creates_configured_directories(tmp_path: Path) -> None:
    root = tmp_path / "images"
    settings = Settings(
        local_image_root=root,
        room_upload_dir=root / "rooms",
        product_image_dir=root / "products",
        generated_image_dir=root / "generated",
    )

    LocalImageStorage(settings)

    assert root.is_dir()
    assert (root / "rooms").is_dir()
    assert (root / "products").is_dir()
    assert (root / "generated").is_dir()


def test_storage_rejects_traversal(tmp_path: Path) -> None:
    storage = LocalImageStorage(
        Settings(
            local_image_root=tmp_path,
            room_upload_dir=tmp_path / "rooms",
            product_image_dir=tmp_path / "products",
            generated_image_dir=tmp_path / "generated",
        )
    )

    try:
        storage.resolve_room_image("../secret.jpeg")
    except Exception as exc:
        assert "Invalid image path" in str(exc)
    else:
        raise AssertionError("path traversal should be rejected")

