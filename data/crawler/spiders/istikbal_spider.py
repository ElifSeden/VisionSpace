from items import FurnitureItem
from extractors.jsonld_extractor import extract_jsonld, get_product_from_jsonld
from extractors.image_extractor import extract_image_urls
from spiders.round_robin import CategoryState, RoundRobinCategorySpider


class IstikbalSpider(RoundRobinCategorySpider):
    name = "istikbal"
    custom_settings = {
        'FEEDS': {'istikbal_urunleri.json': {'format': 'json', 'overwrite': True}},
        'CONCURRENT_REQUESTS_PER_DOMAIN': 1,
    }
    allowed_domains = ["istikbal.com.tr"]
    product_url_contains = ("/urun/", "-p-")

    accepted_categories = [
        {
            "name": "kitchen",
            "url": "https://www.istikbal.com.tr/kategori/yemek-odasi-takimlari",
            "keywords": [],
        },
        {
            "name": "living_room",
            "url": "https://www.istikbal.com.tr/kategori/yatak-odasi-takimlari",
            "keywords": [],
        },
    ]

    def extract_product_links(self, response) -> list[str]:
        links = []
        for href in response.css(".showcase-container .showcase .showcase-title a::attr(href)").getall():
            url = response.urljoin(href.strip())
            if self.is_product_url(url):
                links.append(url)
        return links

    def extract_next_page_url(self, response) -> str | None:
        href = response.css('link[rel="next"]::attr(href)').get()
        if href:
            return response.urljoin(href)
        href = response.css('.pagination a.next::attr(href), .paginate a.next::attr(href), a[rel="next"]::attr(href)').get()
        return response.urljoin(href) if href else None

    def is_product_url(self, url: str) -> bool:
        lowered = url.lower()
        if any(deny in lowered for deny in self.deny_url_contains):
            return False
        return "/urun/" in lowered or "/p/" in lowered or "-p-" in lowered

    def parse_product_response(self, response, state: CategoryState):
        jsonld_data = extract_jsonld(response)
        product_data = get_product_from_jsonld(jsonld_data)

        has_price = bool(response.css('.product-price-new, .product-price, .price-box, [itemprop="price"]'))
        if not (product_data or has_price):
            return None

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
                break

        if not detected_categories:
            css_breadcrumbs = response.css('.breadcrumbs li a::text, .breadcrumbs li strong::text, .breadcrumbs li span::text, .breadcrumb li a::text, .breadcrumb li span::text').getall()
            for cat in css_breadcrumbs:
                clean_cat = cat.strip()
                if clean_cat and clean_cat not in ['>', '/', '-', '|']:
                    detected_categories.append(clean_cat)

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
            item['name'] = response.css('h1.page-title span::text, h1::text').get('').strip()
            item['price'] = response.css('.price-wrapper .price::text, .special-price .price::text').re_first(r'[\d.,]+')
            item['currency'] = "TRY"
            item['id'] = response.css('.sku .value::text, [itemprop="sku"]::text').get('').strip()
            description_texts = response.css('.product.attribute.description .value *::text, #description *::text').getall()
            item['description'] = " ".join([d.strip() for d in description_texts if d.strip()])
            item['metadata'] = {}

        item['image_urls'] = extract_image_urls(response, product_data)
        if not item.get('id'):
            item['id'] = response.url.split('/')[-1].replace('.html', '')
        return item
