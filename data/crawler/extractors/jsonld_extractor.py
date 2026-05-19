import json

def extract_jsonld(response):
    """
    Extracts all JSON-LD data from a Scrapy response.
    Returns a list of parsed JSON objects.
    """
    json_ld_blocks = response.xpath('//script[@type="application/ld+json"]/text()').getall()
    data = []
    for block in json_ld_blocks:
        try:
            # Handle potential edge cases where script content isn't pure JSON
            cleaned_block = block.strip()
            if cleaned_block:
                data.append(json.loads(cleaned_block))
        except json.JSONDecodeError:
            continue
    return data

def get_product_from_jsonld(jsonld_data):
    """
    Finds and returns the Product object from extracted JSON-LD data.
    """
    for item in jsonld_data:
        # Handle if JSON-LD is a list at root
        if isinstance(item, list):
            for sub_item in item:
                if isinstance(sub_item, dict) and sub_item.get('@type') == 'Product':
                    return sub_item
        elif isinstance(item, dict):
            # Sometimes nested in @graph
            if '@graph' in item:
                for graph_item in item['@graph']:
                    if isinstance(graph_item, dict) and graph_item.get('@type') == 'Product':
                        return graph_item
            elif item.get('@type') == 'Product':
                return item
    return None
