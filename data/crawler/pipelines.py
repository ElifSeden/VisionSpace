import os
import json
from scrapy.pipelines.images import ImagesPipeline
from itemadapter import ItemAdapter
from scrapy.exceptions import DropItem


##### sonradan ekledim
class DuplicatesPipeline:
    def __init__(self):
        self.ids_seen = set()
        self.names_seen = set()

    def process_item(self, item, spider):
        adapter = ItemAdapter(item)
        raw_id = adapter.get('id')
        raw_name = adapter.get('name')
        
        # 1. Eğer ID boş geldiyse, direkt ele ki veritabanını bozmasın
        if not raw_id or not raw_name:
            raise DropItem("HATA: Ürünün ID'si veya adı yok (None).")
            
        # 2. ID'nin başındaki/sonundaki boşlukları sil ve büyük harfe çevir (Standartlaştırma)
        clean_id = str(raw_id).strip().upper()


        base_name = str(raw_name).split(',')[0].strip().lower()

        if clean_id in self.ids_seen or base_name in self.names_seen:
            raise DropItem(f"Kopya ürün elendi: {clean_id} - {base_name}")
        else:
            self.ids_seen.add(clean_id)
            self.names_seen.add(base_name)
            # Temizlenmiş ve standartlaşmış ID'yi item'a geri yaz
            item['id'] = clean_id 
            return item

#########
class FurnitureImagePipeline(ImagesPipeline):
    def file_path(self, request, response=None, info=None, *, item=None):
        # Override file path to save images neatly by id
        image_name = request.url.split('/')[-1]
        
        # fallback to default hash-based name if no product id
        if item and item.get("id"):
            # clean up any query strings from the image name
            image_name = image_name.split('?')[0]
            return f'products/{item["id"]}/{image_name}'
            
        return super().file_path(request, response, info, item=item)

    def item_completed(self, results, item, info):
        # Extract the local paths for successfully downloaded images
        image_paths = [x['path'] for ok, x in results if ok]
        adapter = ItemAdapter(item)
        adapter['local_image_paths'] = image_paths
        adapter['image_paths'] = image_paths
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
