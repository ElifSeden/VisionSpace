from app.schemas.ai_outputs import ProductRetrievalIntent
from app.vector.product_search import build_filter_payload


def test_build_filter_payload() -> None:
    payload = build_filter_payload(
        ProductRetrievalIntent(
            role="coffee_table",
            category="coffee_table",
            styles=["scandinavian"],
            material=["wood"],
            colors=["oak"],
            query_text="oak coffee table",
        )
    )
    assert {"key": "category", "match": {"value": "coffee_table"}} in payload["must"]
    assert {"key": "styles", "match": {"any": ["scandinavian"]}} in payload["must"]

