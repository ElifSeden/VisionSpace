from pathlib import Path
from types import SimpleNamespace

from app.vector.product_indexer import (
    _candidate_relative_image_paths,
    _read_image_bytes,
)


def _settings(tmp_path: Path) -> SimpleNamespace:
    return SimpleNamespace(
        product_embedding_image_root=tmp_path / "pipeline" / "output" / "images",
        local_image_root=tmp_path / "images",
        product_image_dir=tmp_path / "images" / "products",
    )


def _product(relative_path: str, external_id: str = "SKU-1") -> SimpleNamespace:
    return SimpleNamespace(
        id="product-id",
        external_id=external_id,
        images=[SimpleNamespace(relative_path=relative_path, is_primary=True, sort_order=0)],
    )


def test_candidate_relative_image_paths_prefers_local_path() -> None:
    product = _product("products/SKU-1/main.jpg")

    assert _candidate_relative_image_paths(product) == ["products/SKU-1/main.jpg"]


def test_candidate_relative_image_paths_maps_legacy_url_to_local_path() -> None:
    product = _product(
        "https://www.istikbal.com.tr/idea/kc/80/myassets/products/826/main.jpg?revision=123",
        external_id="SKU-1",
    )

    assert _candidate_relative_image_paths(product) == ["products/SKU-1/main.jpg"]


def test_read_image_bytes_uses_product_embedding_image_root(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    image_path = settings.product_embedding_image_root / "products" / "SKU-1" / "main.jpg"
    image_path.parent.mkdir(parents=True)
    image_path.write_bytes(b"x" * 1200)

    data, resolved = _read_image_bytes(_product("products/SKU-1/main.jpg"), settings)

    assert data == b"x" * 1200
    assert resolved == image_path.resolve()


def test_candidate_relative_image_paths_tries_secondary_local_path_after_legacy_url() -> None:
    product = SimpleNamespace(
        id="product-id",
        external_id="SKU-1",
        images=[
            SimpleNamespace(
                relative_path="https://example.com/missing.jpg?revision=1",
                is_primary=True,
                sort_order=0,
            ),
            SimpleNamespace(
                relative_path="products/SKU-1/main.jpg",
                is_primary=False,
                sort_order=1,
            ),
        ],
    )

    assert _candidate_relative_image_paths(product) == [
        "products/SKU-1/missing.jpg",
        "products/SKU-1/main.jpg",
    ]
