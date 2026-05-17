import asyncio
import os
import json

from labeler import DesignLabeler
from agent import RoomAgent

def load_scraped_data():
    """
    Reads the generated JSONL file from the Scrapy output.
    """
    output_file = os.path.join(os.path.dirname(__file__), "output", "products.jsonl")
    data = []
    if not os.path.exists(output_file):
        print(f"HATA: Output file not found at {output_file}")
        return data
        
    with open(output_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                data.append(json.loads(line))
    return data

async def main():
    print("1. Loading scraped data...")
    raw_data = load_scraped_data()
    
    print(f"Loaded {len(raw_data)} items from Scrapy output.")
    if not raw_data:
        print("No data to process. Exiting.")
        return
    
    # Load .env file manually if it exists
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_file):
        with open(env_file, 'r') as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, val = line.strip().split('=', 1)
                    os.environ[key] = val.strip("'\"")

    # 2. Label (Loop through raw data and use Gemini)
    print("2. Labeling data with DesignLabeler...")
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable not found. Please set it in your .env file.")
        return
        
    labeler = DesignLabeler(api_key=api_key)
    labeled_inventory = []
    
    # Update loop to use the new item structure
    for idx, data in enumerate(raw_data):
        print(f"Labeling item {idx+1}: {data.get('name', 'Unknown')}")

        try:
            # Pass the local image path instead of just the URL if available
            local_paths = data.get('local_image_paths', [])
            image_source = local_paths[0] if local_paths else data.get('image_urls', [None])[0]
            
            # Note: labeler might need adjustments if it only accepts URLs or base64
            # If it expects an image path, we pass the local absolute path:
            if local_paths:
                image_source = os.path.join(os.path.dirname(__file__), "output", "images", local_paths[0])
            
            # Also adapt data format for the labeler if needed
            # The original script passed data dict directly
            item = labeler.analyze_furniture(image_source, data)
            labeled_inventory.append(item)
        except Exception as e:
            print(f"Ürün etiketlenirken hata oluştu: {e}")
    
    if not labeled_inventory:
         print("No items labeled. Exiting.")
         return

    # 3. Categorize
    print("3. Generating Room Plans...")
    agent = RoomAgent(labeled_inventory)
    plans = agent.generate_plans(budget=50000)

    for category, items in plans.items():
        print(f"Category: {category}")
        for item in items:
            # Assuming 'item' is an object with these attributes, adapt as needed
            print(f"- {item.name}: {item.price_try} TL (Ağırlık: {getattr(item, 'visual_weight', 'N/A')})")

if __name__ == "__main__":
    asyncio.run(main())
