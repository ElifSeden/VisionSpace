import structlog
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.storage.local_storage import LocalImageStorage
from app.utils.composite import render_placeholder_composite
from app.utils.placement import image_size, normalized_to_pixel_polygon
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState

logger = structlog.get_logger(__name__)


def generate_images_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "generate_images")
        settings = get_settings()
        storage = LocalImageStorage(settings)
        room_image_path = state.get("room_image_path", "")
        selected = state.get("selected_products", [])
        if not room_image_path or not selected:
            return {"generated_images": []}

        generated_images = []
        image_width, image_height = image_size(storage.resolve_room_image(room_image_path))
        for strategy in state.get("design_strategies", []):
            design_index = int(strategy["design_index"])
            products = [
                product
                for product in selected
                if int(product.get("design_index", -1)) == design_index and product.get("polygon")
            ]
            if not products:
                continue

            output_relative_path = (
                f"generated/{state['job_id']}/design_{design_index}_composite.png"
            )
            relative_path, output_path = render_placeholder_composite(
                storage=storage,
                room_image_path=room_image_path,
                products=products,
                output_relative_path=output_relative_path,
            )
            generated_images.append(
                {
                    "design_index": design_index,
                    "path": relative_path,
                    "width": image_width,
                    "height": image_height,
                    "renderer": "placeholder_overlay",
                }
            )

            for product in products:
                pixel_polygon = normalized_to_pixel_polygon(
                    product["polygon"],
                    image_width,
                    image_height,
                )
                logger.info(
                    "placement_rendered",
                    job_id=state.get("job_id"),
                    design_index=design_index,
                    selected_furniture_id=str(product.get("product_id")),
                    selected_furniture_image_path=product.get("image_path"),
                    normalized_polygon=product.get("polygon"),
                    pixel_polygon=pixel_polygon,
                    original_image_size={"width": image_width, "height": image_height},
                    final_output_image_path=relative_path,
                )
            logger.info(
                "placeholder_composite_written",
                job_id=state.get("job_id"),
                design_index=design_index,
                output_path=str(output_path),
            )

        return {"generated_images": generated_images}

    return node
