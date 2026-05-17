from typing import List
from models import FurnitureItem
from collections import defaultdict

class RoomAgent:
    def __init__(self, inventory: List[FurnitureItem]):
        self.inventory = inventory

    def generate_plans(self, budget: float):
        return {
            "Symmetrical Minimalist": self._build_minimalist(budget),
            "Dynamic Eclectic": self._build_eclectic(budget),
            "Statement Professional": self._build_statement(budget)
        }

    def _build_minimalist(self, budget):
        affordable = [i for i in self.inventory if i.product_metadata.price_try <= budget]
        if not affordable: return []
        
        groups = defaultdict(list)
        for item in affordable:
            mat = item.product_metadata.specs.material
            if mat != "Unknown":
                groups[mat].append(item)
            
        best_group = []
        for mat, items in groups.items():
            if len(items) > len(best_group):
                best_group = items
                
        if not best_group: return affordable[:2] # Fallback
        
        avg_vw = sum(i.design_dna.visual_weight for i in best_group) / len(best_group)
        
        minimalist_plan = [
            i for i in best_group 
            if avg_vw > 0 and abs(i.design_dna.visual_weight - avg_vw) / avg_vw <= 0.05
        ]
        
        return minimalist_plan if minimalist_plan else best_group[:2]

    def _build_eclectic(self, budget):
        affordable = [i for i in self.inventory if i.product_metadata.price_try <= budget]
        
        def is_contrasting(item):
            body = item.product_metadata.specs.material.lower()
            leg = item.product_metadata.specs.leg_type.lower()
            if not body or not leg or body == "unknown" or leg == "unknown":
                return False
            if body != leg:
                if ("ahşap" in body or "suntalam" in body) and ("metal" in leg or "plastik" in leg):
                    return True
                if "metal" in body and ("ahşap" in leg or "plastik" in leg):
                    return True
            return False

        eclectic_plan = [i for i in affordable if is_contrasting(i)]
        return eclectic_plan

    def _build_statement(self, budget):
        affordable = [i for i in self.inventory if i.product_metadata.price_try <= budget]
        if not affordable: return []
        
        avg_vw = sum(i.design_dna.visual_weight for i in affordable) / len(affordable) if affordable else 0
        
        focal_points = [
            i for i in affordable 
            if i.design_dna.is_focal_point and i.design_dna.visual_weight > avg_vw * 1.5
        ]
        
        neutrals = [
            i for i in affordable 
            if not i.design_dna.is_focal_point and i.design_dna.visual_weight <= avg_vw
        ]
        
        plan = []
        if focal_points:
            plan.append(focal_points[0])
            
        current_cost = sum(i.product_metadata.price_try for i in plan)
        for n in neutrals:
            if current_cost + n.product_metadata.price_try <= budget:
                plan.append(n)
                current_cost += n.product_metadata.price_try
            if len(plan) >= 4:
                break
                
        return plan

    def _calculate_visual_balance(self, items: List[FurnitureItem]):
        total_weight = sum(item.design_dna.visual_weight for item in items)
        return total_weight
