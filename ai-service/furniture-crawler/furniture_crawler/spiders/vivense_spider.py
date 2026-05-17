from scrapy.spiders import CrawlSpider, Rule
from scrapy.linkextractors import LinkExtractor
from furniture_crawler.items import FurnitureItem
from furniture_crawler.extractors.jsonld_extractor import extract_jsonld, get_product_from_jsonld
from furniture_crawler.extractors.image_extractor import extract_image_urls

class VivenseSpider(CrawlSpider):
    name = "vivense"
    allowed_domains = ["vivense.com"]
    start_urls = ["https://www.vivense.com/sitemap.html"]
    
    rules = (
        # Follow all links to discover products
        Rule(LinkExtractor(allow=()), callback='parse_item', follow=True),
    )
    
    def parse_item(self, response):
        # Extract JSON-LD data
        jsonld_data = extract_jsonld(response)
        product_data = get_product_from_jsonld(jsonld_data)
        
        # Fallback to check if it's a product page even without JSON-LD
        # For example, look for add to cart button
        is_product_page = bool(product_data) or bool(response.css('.add-to-cart-button, #add-to-cart'))
        
        if not is_product_page:
            self.logger.debug(f"Not a product page: {response.url}")
            return
            
        item = FurnitureItem()
        item['url'] = response.url
        
        if product_data:
            item['name'] = product_data.get('name')
            item['description'] = product_data.get('description', '')
            
            # Price extraction
            offers = product_data.get('offers', {})
            if isinstance(offers, list) and len(offers) > 0:
                offers = offers[0]
                
            item['price'] = offers.get('price')
            item['currency'] = offers.get('priceCurrency')
            
            # Product ID (SKU)
            item['product_id'] = product_data.get('sku') or product_data.get('productID')
            
            # Metadata
            item['metadata'] = product_data
        else:
            # Fallback extraction from HTML if JSON-LD is missing but it is a product page
            item['name'] = response.css('h1::text').get('').strip()
            item['price'] = response.css('.price::text, .product-price::text').re_first(r'[\d.,]+')
            item['currency'] = "TRY" # Assuming Turkish store as fallback
            item['product_id'] = response.url.split('/')[-1].split('.')[0]
            item['description'] = response.css('.product-description *::text').getall()
            item['metadata'] = {}
            
        # Ensure we have a product ID
        if not item.get('product_id'):
            item['product_id'] = response.url.split('/')[-1].replace('.html', '')
            
        # Extract Images
        image_urls = extract_image_urls(response, product_data)
        item['image_urls'] = image_urls
        
        yield item
