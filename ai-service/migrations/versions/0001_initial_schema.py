"""initial schema

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-05-18
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("external_id", sa.Text(), nullable=False, unique=True),
        sa.Column("source", sa.Text()),
        sa.Column("source_url", sa.Text()),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("category", sa.Text(), nullable=False),
        sa.Column("price_amount", sa.Numeric()),
        sa.Column("price_currency", sa.Text()),
        sa.Column("width_cm", sa.Numeric()),
        sa.Column("depth_cm", sa.Numeric()),
        sa.Column("height_cm", sa.Numeric()),
        sa.Column("material", postgresql.ARRAY(sa.Text())),
        sa.Column("colors", postgresql.ARRAY(sa.Text())),
        sa.Column("styles", postgresql.ARRAY(sa.Text())),
        sa.Column("temperature", sa.Text()),
        sa.Column("room_types", postgresql.ARRAY(sa.Text())),
        sa.Column("is_group", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("group_items", postgresql.JSONB()),
        sa.Column("raw_metadata", postgresql.JSONB()),
        sa.Column("enriched_metadata", postgresql.JSONB()),
        sa.Column("metadata_confidence", postgresql.JSONB()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("idx_products_category", "products", ["category"])
    op.create_index("idx_products_is_active", "products", ["is_active"])
    op.create_index("idx_products_is_group", "products", ["is_group"])
    op.create_index("idx_products_styles", "products", ["styles"], postgresql_using="gin")
    op.create_index("idx_products_colors", "products", ["colors"], postgresql_using="gin")
    op.create_index("idx_products_material", "products", ["material"], postgresql_using="gin")
    op.create_index("idx_products_room_types", "products", ["room_types"], postgresql_using="gin")

    op.create_table(
        "product_images",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("image_type", sa.Text(), nullable=False),
        sa.Column("relative_path", sa.Text(), nullable=False),
        sa.Column("width", sa.Integer()),
        sa.Column("height", sa.Integer()),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "design_jobs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("status", sa.Text(), nullable=False),
        sa.Column("input_room_image_path", sa.Text(), nullable=False),
        sa.Column("room_dimensions", postgresql.JSONB(), nullable=False),
        sa.Column("user_preferences", postgresql.JSONB(), nullable=False),
        sa.Column("replace_existing_furniture", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("requested_design_count", sa.Integer(), nullable=False, server_default="3"),
        sa.Column("workflow_state", postgresql.JSONB()),
        sa.Column("error_message", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
    )
    op.create_index("idx_design_jobs_status", "design_jobs", ["status"])

    op.create_table(
        "generated_designs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("design_job_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("design_jobs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("design_index", sa.Integer(), nullable=False),
        sa.Column("title", sa.Text()),
        sa.Column("style", sa.Text()),
        sa.Column("summary", sa.Text()),
        sa.Column("generated_image_path", sa.Text()),
        sa.Column("room_analysis", postgresql.JSONB()),
        sa.Column("placement_plan", postgresql.JSONB()),
        sa.Column("confidence", postgresql.JSONB()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "selected_products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("generated_design_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("generated_designs.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("role", sa.Text(), nullable=False),
        sa.Column("reason", sa.Text()),
        sa.Column("polygon", postgresql.JSONB()),
        sa.Column("score", sa.Numeric()),
        sa.Column("metadata", postgresql.JSONB()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("selected_products")
    op.drop_table("generated_designs")
    op.drop_index("idx_design_jobs_status", table_name="design_jobs")
    op.drop_table("design_jobs")
    op.drop_table("product_images")
    op.drop_index("idx_products_room_types", table_name="products")
    op.drop_index("idx_products_material", table_name="products")
    op.drop_index("idx_products_colors", table_name="products")
    op.drop_index("idx_products_styles", table_name="products")
    op.drop_index("idx_products_is_group", table_name="products")
    op.drop_index("idx_products_is_active", table_name="products")
    op.drop_index("idx_products_category", table_name="products")
    op.drop_table("products")

