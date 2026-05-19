from sqlalchemy.orm import Session

from app.schemas.product import ProductCandidate, ProductSearchRequest
from app.vector.product_search import search_products


class ProductService:
    def __init__(self, db: Session):
        self.db = db

    def search(self, request: ProductSearchRequest) -> list[ProductCandidate]:
        return search_products(self.db, request, request.limit)

