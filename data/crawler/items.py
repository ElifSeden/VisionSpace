import scrapy

class FurnitureItem(scrapy.Item):
    # Basic information
    id = scrapy.Field()
    name = scrapy.Field()
    price = scrapy.Field()
    currency = scrapy.Field()
    url = scrapy.Field()
    description = scrapy.Field()
    # sonradan ekledim Category and subcategory
    category = scrapy.Field()
    attributes = scrapy.Field()
    
    metadata = scrapy.Field()
    # Additional metadata extracted from the page
    breadcrumbs = scrapy.Field()
    
    # Fields required by ImagesPipeline
    image_urls = scrapy.Field()
    images = scrapy.Field()
    #local yerine image paths yapabiliriz, çünkü pipeline'da zaten images klasörüne kaydedilecekler
    image_paths = scrapy.Field()
    
    # Stored local paths from the image pipeline
    local_image_paths = scrapy.Field()
