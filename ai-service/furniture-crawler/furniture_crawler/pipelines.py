import os
import json
from scrapy.pipelines.images import ImagesPipeline
from itemadapter import ItemAdapter

class FurnitureImagePipeline(ImagesPipeline):
    def file_path(self, request, response=None, info=None, *, item=None):
        # Override file path to save images neatly by product_id
        image_name = request.url.split('/')[-1]
        
        # fallback to default hash-based name if no product id
        if item and item.get("product_id"):
            # clean up any query strings from the image name
            image_name = image_name.split('?')[0]
            return f'products/{item["product_id"]}/{image_name}'
            
        return super().file_path(request, response, info, item=item)

    def item_completed(self, results, item, info):
        # Extract the local paths for successfully downloaded images
        image_paths = [x['path'] for ok, x in results if ok]
        adapter = ItemAdapter(item)
        if image_paths:
            adapter['local_image_paths'] = image_paths
        else:
            adapter['local_image_paths'] = []
        return item

class JsonExportPipeline:
    def open_spider(self, spider):
        # Ensure output directory exists
        images_store = spider.settings.get('IMAGES_STORE')
        output_dir = os.path.dirname(images_store)
        os.makedirs(output_dir, exist_ok=True)
        
        # Open jsonl file for appending/writing
        file_path = os.path.join(output_dir, 'products.jsonl')
        self.file = open(file_path, 'w', encoding='utf-8')

    def close_spider(self, spider):
        self.file.close()

    def process_item(self, item, spider):
        # Write item to JSONL
        line = json.dumps(ItemAdapter(item).asdict(), ensure_ascii=False) + "\n"
        self.file.write(line)
        return item
