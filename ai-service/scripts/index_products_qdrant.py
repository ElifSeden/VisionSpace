from app.db.session import new_session
from app.vector.product_indexer import index_products


def main() -> None:
    with new_session() as db:
        count = index_products(db)
    print(f"Indexed {count} products")


if __name__ == "__main__":
    main()
