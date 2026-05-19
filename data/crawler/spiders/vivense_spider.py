from items import FurnitureItem
from extractors.jsonld_extractor import extract_jsonld, get_product_from_jsonld
from extractors.image_extractor import extract_image_urls
from spiders.round_robin import CategoryState, RoundRobinCategorySpider


class VivenseSpider(RoundRobinCategorySpider):
    name = "vivense"
    allowed_domains = ["vivense.com"]
    custom_settings = {
        'FEEDS': {'vivense_urunleri.json': {'format': 'json', 'overwrite': True}},
        'CONCURRENT_REQUESTS_PER_DOMAIN': 1,
    }
    product_url_contains = ("-modeli.html",)

    accepted_categories = [
        {"name": "kitchen", "url": "https://www.vivense.com/yemek-odasi-mutfak.html", "keywords": []},
        {"name": "living_room", "url": "https://www.vivense.com/yatak-odasi.html", "keywords": []},
    ]

    def extract_product_links(self, response) -> list[str]:
        links = []
        for href in response.css("#product-list-wrapper .product-list .product-card[data-url]::attr(data-url)").getall():
            url = response.urljoin(href.strip())
            if self.is_product_url(url):
                links.append(url)
        return links

    def parse_product_response(self, response, state: CategoryState):
        jsonld_data = extract_jsonld(response)

        detected_categories = []
        for block in jsonld_data:
            if isinstance(block, dict) and block.get('@type') == 'BreadcrumbList':
                items = block.get('itemListElement', [])
                for element in items:
                    cat_name = None
                    if isinstance(element, dict):
                        item_data = element.get('item')
                        if isinstance(item_data, dict):
                            cat_name = item_data.get('name')
                        if not cat_name:
                            cat_name = element.get('name')
                    elif isinstance(element, str):
                        cat_name = element

                    if cat_name and isinstance(cat_name, str):
                        detected_categories.append(cat_name.strip())

        product_data = get_product_from_jsonld(jsonld_data)
        is_product_page = bool(product_data) or bool(response.css('.add-to-cart-button, #add-to-cart'))
        if not is_product_page:
            self.logger.debug("Not a product page: %s", response.url)
            return None

        item = FurnitureItem()
        item['url'] = response.url
        item['category'] = state.name
        item['breadcrumbs'] = detected_categories

        if product_data:
            item['name'] = product_data.get('name')
            item['description'] = product_data.get('description', '')
            offers = product_data.get('offers', {})
            if isinstance(offers, list) and len(offers) > 0:
                offers = offers[0]
            item['price'] = offers.get('price')
            item['currency'] = offers.get('priceCurrency')
            item['id'] = product_data.get('sku') or product_data.get('productID')
            item['metadata'] = product_data
        else:
            item['name'] = response.css('h1::text').get('').strip()
            item['price'] = response.css('.price::text, .product-price::text').re_first(r'[\d.,]+')
            item['currency'] = "TRY"
            item['id'] = response.url.split('/')[-1].split('.')[0]
            item['description'] = response.css('.product-description *::text').getall()
            item['metadata'] = {}

        if not item.get('id'):
            item['id'] = response.url.split('/')[-1].replace('.html', '')

        item['image_urls'] = extract_image_urls(response, product_data)
        return item
