from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.orm import Session, selectinload

from app.db.models.product import Product
from app.db.models.product_image import ProductImage
from app.schemas.ai_outputs import ProductRetrievalIntent


class ProductRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, product_id: UUID) -> Product | None:
        return self.db.get(Product, product_id)

    def get_many(self, product_ids: list[UUID]) -> list[Product]:
        if not product_ids:
            return []
        stmt = select(Product).where(Product.id.in_(product_ids)).options(selectinload(Product.images))
        return list(self.db.scalars(stmt))

    def upsert_product(self, item: dict) -> Product:
        product = self.db.scalar(select(Product).where(Product.external_id == item["external_id"]))
        if product is None:
            product = Product(external_id=item["external_id"])
            self.db.add(product)

        price = item.get("price") or {}
        dimensions = item.get("dimensions") or {}
        product.source = item.get("source")
        product.source_url = item.get("source_url")
        product.name = item["name"]
        product.description = item.get("description")
        product.category = item["category"]
        product.price_amount = price.get("amount")
        product.price_currency = price.get("currency")
        product.width_cm = dimensions.get("width_cm")
        product.depth_cm = dimensions.get("depth_cm")
        product.height_cm = dimensions.get("height_cm")
        product.material = item.get("material") or []
        product.colors = item.get("colors") or []
        product.styles = item.get("styles") or []
        product.temperature = item.get("temperature")
        product.room_types = item.get("room_types") or []
        product.is_group = bool(item.get("is_group", False))
        product.group_items = item.get("group_items") or []
        product.raw_metadata = item.get("raw_metadata") or {}
        product.enriched_metadata = item.get("enriched_metadata") or {}
        product.metadata_confidence = item.get("metadata_confidence") or {}
        product.is_active = bool(item.get("is_active", True))
        self.db.flush()
        return product

    def upsert_images(self, product: Product, images: list[dict]) -> None:
        existing = {(img.relative_path, img.image_type): img for img in product.images}
        for index, image in enumerate(images):
            relative_path = image.get("relative_path")
            if not relative_path:
                continue
            image_type = image.get("image_type") or "primary"
            record = existing.get((relative_path, image_type))
            if record is None:
                record = ProductImage(product_id=product.id, relative_path=relative_path, image_type=image_type)
                self.db.add(record)
            record.width = image.get("width")
            record.height = image.get("height")
            record.sort_order = image.get("sort_order", index)
            record.is_primary = bool(image.get("is_primary", index == 0))

    def fallback_search(self, intent: ProductRetrievalIntent, limit: int = 50) -> list[Product]:
        conditions = [Product.is_active.is_(True), Product.category == intent.category]
        if not intent.is_group_allowed:
            conditions.append(Product.is_group.is_(False))
        if intent.temperature:
            conditions.append(or_(Product.temperature == intent.temperature, Product.temperature.is_(None)))
        if intent.styles:
            conditions.append(or_(Product.styles.overlap(intent.styles), Product.styles.is_(None)))
        if intent.material:
            conditions.append(or_(Product.material.overlap(intent.material), Product.material.is_(None)))
        if intent.colors:
            conditions.append(or_(Product.colors.overlap(intent.colors), Product.colors.is_(None)))
        if intent.room_types:
            conditions.append(or_(Product.room_types.overlap(intent.room_types), Product.room_types.is_(None)))
        if intent.max_width_cm:
            conditions.append(or_(Product.width_cm <= intent.max_width_cm, Product.width_cm.is_(None)))
        if intent.max_depth_cm:
            conditions.append(or_(Product.depth_cm <= intent.max_depth_cm, Product.depth_cm.is_(None)))
        if intent.max_height_cm:
            conditions.append(or_(Product.height_cm <= intent.max_height_cm, Product.height_cm.is_(None)))

        stmt = (
            select(Product)
            .where(and_(*conditions))
            .options(selectinload(Product.images))
            .limit(limit)
        )
        return list(self.db.scalars(stmt))
