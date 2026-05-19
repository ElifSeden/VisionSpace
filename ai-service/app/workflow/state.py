from typing import TypedDict


class DesignWorkflowState(TypedDict, total=False):
    job_id: str
    room_image_path: str
    room_dimensions: dict
    user_preferences: dict
    requested_design_count: int
    room_analysis: dict
    design_strategies: list[dict]
    retrieval_intents: list[dict]
    candidate_products: dict
    selected_products: list[dict]
    placement_plan: dict
    generated_images: list[dict]
    final_designs: list[dict]
    current_stage: str
    errors: list[dict]

