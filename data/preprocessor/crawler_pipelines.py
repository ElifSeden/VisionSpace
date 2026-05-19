from itemadapter import ItemAdapter


SOURCE_CATEGORY_ROOM_HINTS = {
    "kitchen": ["kitchen", "dining_room"],
    "dining_room": ["dining_room", "kitchen"],
    "living_room": ["living_room"],
    "bedroom": ["bedroom"],
    "office": ["office"],
    "hallway": ["hallway"],
    "outdoor": ["outdoor", "balcony"],
}


def normalize_source_category(value):
    if value in (None, "", [], {}):
        return None
    return str(value).strip().lower().replace(" ", "_").replace("-", "_")


class DataEnrichmentPipeline:
    def process_item(self, item, spider):
        adapter = ItemAdapter(item)
        source_category = normalize_source_category(adapter.get("category"))

        attributes = {
            "color": ["unknown"],
            "material": ["unknown"],
            "style": ["modern"],
            "room": SOURCE_CATEGORY_ROOM_HINTS.get(source_category, ["unknown"]),
            "temperature": "unknown",
            "size": adapter.get("size") or adapter.get("dimensions") or "unknown",
        }

        if source_category:
            adapter["source_category"] = source_category
        if not adapter.get("category"):
            adapter["category"] = "unknown"

        adapter["attributes"] = attributes
        return item
