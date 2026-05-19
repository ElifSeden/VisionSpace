from __future__ import annotations

from collections import deque
from dataclasses import dataclass, field
from itertools import cycle
from typing import Iterable

import scrapy


def parse_bool(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


@dataclass
class CategoryState:
    name: str
    url: str
    keywords: list[str]
    product_urls: deque[str] = field(default_factory=deque)
    seen_product_urls: set[str] = field(default_factory=set)
    next_page_url: str | None = None
    next_page_meta: dict[str, object] = field(default_factory=dict)
    page_in_flight: bool = False
    product_in_flight: bool = False
    exhausted: bool = False
    scraped_count: int = 0


class RoundRobinCategorySpider(scrapy.Spider):
    """Scrape accepted categories in a per-category round-robin order.

    Pass ``-a target_per_category=100`` to scrape up to 100 products from each
    accepted category. Pass ``-a scrape_until_finished=true`` to ignore the
    target and keep going until every category has no products/pages left.
    """

    accepted_categories: list[dict[str, object]] = []
    product_url_contains: tuple[str, ...] = ()
    product_url_regexes: tuple[str, ...] = ()
    deny_url_contains: tuple[str, ...] = (
        "/cart",
        "/checkout",
        "/customer",
        "/login",
        "/iletisim",
        "#",
    )

    def __init__(
        self,
        target_per_category: int | str | None = None,
        target_products: int | str | None = None,
        scrape_until_finished: bool | str = False,
        categories: str | None = None,
        *args,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.scrape_until_finished = parse_bool(scrape_until_finished)
        raw_target = target_per_category if target_per_category is not None else target_products
        self.target_per_category = self._parse_target(raw_target)
        if self.scrape_until_finished:
            self.target_per_category = None

        selected_categories = self._parse_categories(categories)
        accepted_categories = [
            category
            for category in self.accepted_categories
            if not selected_categories or str(category["name"]) in selected_categories
        ]

        self.category_states = {
            str(category["name"]): CategoryState(
                name=str(category["name"]),
                url=str(category["url"]),
                keywords=[str(keyword).lower() for keyword in category.get("keywords", [])],
            )
            for category in accepted_categories
        }
        self.category_order = list(self.category_states)
        self._round_robin = cycle(self.category_order) if self.category_order else None

    @staticmethod
    def _parse_target(value: int | str | None) -> int | None:
        if value in (None, "", "all", "none"):
            return None
        target = int(value)
        if target <= 0:
            raise ValueError("target_per_category must be greater than zero")
        return target

    @staticmethod
    def _parse_categories(value: str | None) -> set[str]:
        if value in (None, "", "all"):
            return set()
        return {part.strip() for part in str(value).split(",") if part.strip()}

    def start_requests(self):
        if not self.category_states:
            self.logger.warning("No accepted categories configured for %s", self.name)
            return

        for state in self.category_states.values():
            state.page_in_flight = True
            yield scrapy.Request(
                state.url,
                callback=self.parse_category,
                meta={"category_name": state.name},
                dont_filter=True,
            )

    def parse_category(self, response):
        state = self.category_states[response.meta["category_name"]]
        state.page_in_flight = False

        product_urls = self.extract_product_links(response)
        for url in product_urls:
            if url not in state.seen_product_urls:
                state.seen_product_urls.add(url)
                state.product_urls.append(url)

        state.next_page_url = self.extract_next_page_url(response)
        if not state.product_urls and not state.next_page_url:
            state.exhausted = True

        yield from self.schedule_next_round()

    def parse_next_page(self, response):
        yield from self.parse_category(response)

    def parse_product(self, response):
        state = self.category_states[response.meta["category_name"]]
        item = self.parse_product_response(response, state)

        if item is not None and not self.category_target_reached(state):
            if not item.get("category"):
                item["category"] = state.name
            state.scraped_count += 1
            yield item

        state.product_in_flight = False
        yield from self.schedule_next_round()

    def schedule_next_round(self):
        if not self._round_robin:
            return

        for _ in self.category_order:
            state = self.category_states[next(self._round_robin)]
            if self.category_target_reached(state):
                state.exhausted = True
                continue
            if state.product_in_flight or state.page_in_flight:
                continue
            if state.product_urls:
                state.product_in_flight = True
                yield scrapy.Request(
                    state.product_urls.popleft(),
                    callback=self.parse_product,
                    meta={"category_name": state.name},
                    dont_filter=False,
                )
                return
            if state.next_page_url:
                next_page_url = state.next_page_url
                state.next_page_url = None
                state.page_in_flight = True
                yield scrapy.Request(
                    next_page_url,
                    callback=self.parse_next_page,
                    meta={"category_name": state.name, **state.next_page_meta},
                    dont_filter=False,
                )
                state.next_page_meta = {}
                return
            state.exhausted = True

    def category_target_reached(self, state: CategoryState) -> bool:
        return self.target_per_category is not None and state.scraped_count >= self.target_per_category

    def extract_product_links(self, response) -> list[str]:
        links = []
        for href in response.css("a::attr(href)").getall():
            url = response.urljoin(href.strip())
            if self.is_product_url(url):
                links.append(url)
        return links

    def is_product_url(self, url: str) -> bool:
        lowered = url.lower()
        if any(deny in lowered for deny in self.deny_url_contains):
            return False
        if self.product_url_contains and any(part in lowered for part in self.product_url_contains):
            return True
        return False

    def extract_next_page_url(self, response) -> str | None:
        selectors = (
            'a[rel="next"]::attr(href)',
            'a.next::attr(href)',
            '.pagination a.next::attr(href)',
            '.pager a.next::attr(href)',
            'li.next a::attr(href)',
        )
        for selector in selectors:
            href = response.css(selector).get()
            if href:
                return response.urljoin(href)
        return None

    def category_matches(self, detected_categories: Iterable[str], state: CategoryState) -> bool:
        category_text = " ".join(category.lower() for category in detected_categories)
        return not state.keywords or any(keyword in category_text for keyword in state.keywords)

    def parse_product_response(self, response, state: CategoryState):
        raise NotImplementedError
