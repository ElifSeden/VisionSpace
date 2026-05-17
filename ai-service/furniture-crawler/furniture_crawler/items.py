import scrapy

class FurnitureItem(scrapy.Item):
    # Basic information
    product_id = scrapy.Field()
    name = scrapy.Field()
    price = scrapy.Field()
    currency = scrapy.Field()
    url = scrapy.Field()
    description = scrapy.Field()
    
    # Additional metadata extracted from the page
    metadata = scrapy.Field()
    
    # Fields required by ImagesPipeline
    image_urls = scrapy.Field()
    images = scrapy.Field()
    
    # Stored local paths from the pipeline
    local_image_paths = scrapy.Field()
