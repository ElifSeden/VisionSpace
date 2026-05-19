import sys
from pathlib import Path

from scrapy.crawler import CrawlerProcess
from scrapy.utils.project import get_project_settings

PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from spiders.ikea_spider import IkeaSpider
from spiders.istikbal_spider import IstikbalSpider
from spiders.vivense_spider import VivenseSpider


SPIDERS = {
    "ikea": IkeaSpider,
    "vivense": VivenseSpider,
    "istikbal": IstikbalSpider,
}


def prompt_required(message: str) -> str:
    while True:
        value = input(message).strip()
        if value:
            return value
        print("Please enter a value.")


def choose_from_list(title: str, options: list[str], allow_all: bool = True) -> list[str]:
    print(f"\n{title}")
    if allow_all:
        print("  all) All")
    for index, option in enumerate(options, start=1):
        print(f"  {index}) {option}")

    while True:
        raw = prompt_required("Select comma-separated numbers/names or 'all': ")
        selected = parse_selection(raw, options, allow_all=allow_all)
        if selected:
            return selected
        print("No valid selection. Try again.")


def parse_selection(raw: str, options: list[str], allow_all: bool = True) -> list[str]:
    normalized = raw.strip().lower()
    if allow_all and normalized in {"all", "a", "*"}:
        return list(options)

    selected: list[str] = []
    option_lookup = {option.lower(): option for option in options}
    for part in raw.split(","):
        token = part.strip()
        if not token:
            continue
        if token.isdigit():
            index = int(token)
            if 1 <= index <= len(options):
                selected.append(options[index - 1])
            continue
        option = option_lookup.get(token.lower())
        if option:
            selected.append(option)

    deduped: list[str] = []
    for option in selected:
        if option not in deduped:
            deduped.append(option)
    return deduped


def choose_run_mode() -> tuple[int | None, bool]:
    print("\nRun mode")
    print("  1) Limit products per category")
    print("  2) Scrape until each selected category is finished")

    while True:
        choice = prompt_required("Select 1 or 2: ")
        if choice == "1":
            return choose_target_amount(), False
        if choice == "2":
            return None, True
        print("Invalid choice. Select 1 or 2.")


def choose_target_amount() -> int:
    while True:
        raw = prompt_required("Products per selected category: ")
        try:
            amount = int(raw)
        except ValueError:
            print("Enter a whole number greater than 0.")
            continue
        if amount > 0:
            return amount
        print("Amount must be greater than 0.")


def category_names(spider_cls) -> list[str]:
    return [str(category["name"]) for category in spider_cls.accepted_categories]


def main() -> None:
    selected_spiders = choose_from_list("Spiders", sorted(SPIDERS), allow_all=True)

    selected_categories: dict[str, list[str]] = {}
    for spider_name in selected_spiders:
        names = category_names(SPIDERS[spider_name])
        if not names:
            selected_categories[spider_name] = []
            continue
        selected_categories[spider_name] = choose_from_list(
            f"Categories for {spider_name}",
            names,
            allow_all=True,
        )

    target_per_category, until_finished = choose_run_mode()

    print("\nStarting crawler with:")
    print(f"  spiders: {', '.join(selected_spiders)}")
    for spider_name in selected_spiders:
        categories = selected_categories.get(spider_name) or category_names(SPIDERS[spider_name])
        print(f"  {spider_name} categories: {', '.join(categories) if categories else 'all'}")
    if until_finished:
        print("  mode: until finished")
    else:
        print(f"  mode: {target_per_category} products per category")

    settings = get_project_settings()
    process = CrawlerProcess(settings)

    for spider_name in selected_spiders:
        categories = selected_categories.get(spider_name, [])
        process.crawl(
            SPIDERS[spider_name],
            categories=",".join(categories) if categories else None,
            target_per_category=target_per_category,
            scrape_until_finished=until_finished,
        )

    process.start()
    print("Crawler finished.")


if __name__ == "__main__":
    main()
