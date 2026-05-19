from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.product import ProductCandidate, ProductSearchRequest
from app.services.product_service import ProductService

router = APIRouter(prefix="/products", tags=["products"])


@router.post("/search", response_model=list[ProductCandidate])
def search_products(request: ProductSearchRequest, db: Session = Depends(get_db)) -> list[ProductCandidate]:
    return ProductService(db).search(request)

