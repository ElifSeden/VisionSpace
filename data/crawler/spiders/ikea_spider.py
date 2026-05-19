import json
from urllib.parse import urlencode

import scrapy

from items import FurnitureItem
from extractors.jsonld_extractor import extract_jsonld, get_product_from_jsonld
from extractors.image_extractor import extract_image_urls
from spiders.round_robin import CategoryState, RoundRobinCategorySpider


class IkeaSpider(RoundRobinCategorySpider):
    name = "ikea"
    custom_settings = {
        'FEEDS': {'ikea_urunleri.json': {'format': 'json', 'overwrite': True}},
        'CONCURRENT_REQUESTS_PER_DOMAIN': 1,
    }
    allowed_domains = ["ikea.com.tr", "frontendapi.ikea.com.tr"]
    product_url_contains = ("/urun/",)
    api_page_size = 24

    accepted_categories = [
        {
            "name": "kitchen",
            "url": "https://www.ikea.com.tr/kategori/yemek-odasi-mobilyalari",
            "api_category": "yemek-odasi-mobilyalari",
            "keywords": [],
        },
        {
            "name": "living_room",
            "url": "https://www.ikea.com.tr/kategori/yatak-odasi-mobilyalari",
            "api_category": "yatak-odasi-mobilyalari",
            "keywords": [],
        },
    ]

    def parse_category(self, response):
        state = self.category_states[response.meta["category_name"]]
        state.page_in_flight = False

        api_category = response.css('#ctl00_ContentPlaceHolder1_search_categoryUrl::attr(value)').get()
        if not api_category:
            api_category = self.category_config(state.name).get("api_category")
        if not api_category:
            self.logger.warning("IKEA category id not found for %s", state.name)
            state.exhausted = True
            yield from self.schedule_next_round()
            return

        state.page_in_flight = True
        yield scrapy.Request(
            self.build_api_url(str(api_category), page=1),
            callback=self.parse_api_category,
            meta={"category_name": state.name, "api_category": str(api_category), "page": 1},
            dont_filter=True,
        )

    def parse_api_category(self, response):
        state = self.category_states[response.meta["category_name"]]
        state.page_in_flight = False
        page = int(response.meta["page"])
        api_category = response.meta["api_category"]

        try:
            payload = json.loads(response.text)
        except json.JSONDecodeError as exc:
            self.logger.warning("IKEA API response is not JSON for %s page %s: %s", state.name, page, exc)
            state.exhausted = True
            yield from self.schedule_next_round()
            return

        products = payload.get("products") or []
        for product in products:
            if product.get("type") == "cbm":
                continue
            href = product.get("url")
            if not href:
                continue
            href = str(href).strip()
            if href.startswith("/"):
                url = f"https://www.ikea.com.tr{href}"
            else:
                url = response.urljoin(href)
            if url not in state.seen_product_urls and self.is_product_url(url):
                state.seen_product_urls.add(url)
                state.product_urls.append(url)

        total = int(payload.get("total") or 0)
        applied_size = int(payload.get("appliedSize") or self.api_page_size)
        if page * applied_size < total and products:
            state.next_page_url = self.build_api_url(api_category, page=page + 1)
            state.next_page_meta = {"api_category": api_category, "page": page + 1}
        else:
            state.next_page_url = None
            state.next_page_meta = {}
            if not state.product_urls:
                state.exhausted = True

        yield from self.schedule_next_round()

    def parse_next_page(self, response):
        yield from self.parse_api_category(response)

    def build_api_url(self, category: str, page: int) -> str:
        params = {
            "language": "tr",
            "Category": category,
            "IncludeFilters": "false",
            "StoreCode": "",
            "sortby": "None",
            "size": str(self.api_page_size),
            "SearchFrom": "Category",
            "IncludeColorVariants": "true",
        }
        if page > 1:
            params["page"] = str(page)
        return f"https://frontendapi.ikea.com.tr/api/search/products?{urlencode(params)}"

    def category_config(self, category_name: str) -> dict[str, object]:
        for category in self.accepted_categories:
            if category.get("name") == category_name:
                return category
        return {}

    def parse_product_response(self, response, state: CategoryState):
        jsonld_data = extract_jsonld(response)
        product_data = get_product_from_jsonld(jsonld_data)

        has_price = bool(response.css('.pip-temp-price, .pip-temp-price__integer, [itemprop="price"]'))
        if not (product_data or has_price):
            return None

        detected_categories = self.extract_breadcrumbs(response, jsonld_data)

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
            item['name'] = response.css('h1::text, .pip-header-section__title--big::text').get('').strip()
            item['price'] = response.css('.pip-temp-price__integer::text').re_first(r'[\d.,]+')
            item['currency'] = "TRY"
            item['id'] = response.css('.pip-product-identifier__value::text').get('').strip()
            description_texts = response.css('.pip-product-summary__description::text, .pip-product-details__paragraph::text').getall()
            item['description'] = " ".join([d.strip() for d in description_texts if d.strip()])
            item['metadata'] = {}

        if not item.get('id'):
            item['id'] = response.url.split('/')[-1].replace('.html', '')

        item['image_urls'] = extract_image_urls(response, product_data)
        return item

    def extract_breadcrumbs(self, response, jsonld_data):
        detected_categories = []
        for block in jsonld_data:
            if isinstance(block, dict) and block.get('@type') == 'BreadcrumbList':
                for element in block.get('itemListElement', []):
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
            css_breadcrumbs = response.css('.bc-breadcrumb__item span::text, .bc-breadcrumb__item a::text').getall()
            for cat in css_breadcrumbs:
                clean_cat = cat.strip()
                if clean_cat and clean_cat not in ['>', '/', '-', '|']:
                    detected_categories.append(clean_cat)
        return detected_categories
