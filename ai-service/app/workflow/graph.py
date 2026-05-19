import structlog
from langgraph.graph import END, StateGraph
from sqlalchemy.orm import Session

from app.core.constants import JOB_STATUS_FAILED, JOB_STATUS_RUNNING
from app.db.repositories.design_job_repository import DesignJobRepository
from app.workflow.nodes.analyze_room import analyze_room_node
from app.workflow.nodes.create_design_strategies import create_design_strategies_node
from app.workflow.nodes.generate_images import generate_images_node
from app.workflow.nodes.persist_result import persist_result_node
from app.workflow.nodes.plan_placements import plan_placements_node
from app.workflow.nodes.rerank_products import rerank_products_node
from app.workflow.nodes.retrieve_candidates import retrieve_candidates_node
from app.workflow.nodes.validate_input import validate_input_node
from app.workflow.nodes.validate_result import validate_result_node
from app.workflow.state import DesignWorkflowState

logger = structlog.get_logger(__name__)


def build_graph(db: Session):
    graph = StateGraph(DesignWorkflowState)
    graph.add_node("validate_input", validate_input_node(db))
    graph.add_node("analyze_room", analyze_room_node(db))
    graph.add_node("create_design_strategies", create_design_strategies_node(db))
    graph.add_node("retrieve_candidates", retrieve_candidates_node(db))
    graph.add_node("rerank_products", rerank_products_node(db))
    graph.add_node("plan_placements", plan_placements_node(db))
    graph.add_node("generate_images", generate_images_node(db))
    graph.add_node("validate_result", validate_result_node(db))
    graph.add_node("persist_result", persist_result_node(db))

    graph.set_entry_point("validate_input")
    graph.add_edge("validate_input", "analyze_room")
    graph.add_edge("analyze_room", "create_design_strategies")
    graph.add_edge("create_design_strategies", "retrieve_candidates")
    graph.add_edge("retrieve_candidates", "rerank_products")
    graph.add_edge("rerank_products", "plan_placements")
    graph.add_edge("plan_placements", "generate_images")
    graph.add_edge("generate_images", "validate_result")
    graph.add_edge("validate_result", "persist_result")
    graph.add_edge("persist_result", END)
    return graph.compile()


def run_design_workflow(db: Session, state: DesignWorkflowState) -> DesignWorkflowState:
    repo = DesignJobRepository(db)
    job = repo.get(state["job_id"])
    if job:
        repo.update_status(job, JOB_STATUS_RUNNING)
    try:
        result = build_graph(db).invoke(state)
        return result
    except Exception as exc:
        logger.exception("design_workflow_failed", job_id=state.get("job_id"), error=str(exc))
        job = repo.get(state["job_id"])
        if job:
            job.workflow_state = {**state, "current_stage": state.get("current_stage"), "errors": [{"message": str(exc)}]}
            repo.update_status(job, JOB_STATUS_FAILED, str(exc))
        raise

