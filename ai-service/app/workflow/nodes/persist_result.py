from sqlalchemy.orm import Session

from app.db.repositories.design_job_repository import DesignJobRepository
from app.workflow.nodes.helpers import progress
from app.workflow.state import DesignWorkflowState


def persist_result_node(db: Session):
    def node(state: DesignWorkflowState) -> DesignWorkflowState:
        progress(db, state, "persist_result")
        final_designs = []
        selected = state.get("selected_products", [])
        generated_by_index = {
            int(image["design_index"]): image for image in state.get("generated_images", [])
        }
        for strategy in state.get("design_strategies", []):
            design_index = int(strategy["design_index"])
            products = [p for p in selected if int(p["design_index"]) == design_index]
            generated_image = generated_by_index.get(design_index)
            final_designs.append(
                {
                    "design_index": design_index,
                    "title": strategy.get("title"),
                    "style": strategy.get("style"),
                    "summary": strategy.get("notes")
                    or "Generated from selected catalog products and placement metadata.",
                    "generated_image_path": (
                        generated_image.get("path") if generated_image else None
                    ),
                    "placement_debug": state.get("placement_debug"),
                    "products": products,
                }
            )
        job = DesignJobRepository(db).get(state["job_id"])
        if job:
            job.workflow_state = {
                **state,
                "final_designs": final_designs,
                "current_stage": "completed",
            }
            DesignJobRepository(db).persist_results(job, final_designs, state.get("room_analysis"))
        return {"final_designs": final_designs, "current_stage": "completed"}

    return node
