import argparse

from scrapy.crawler import CrawlerProcess
from scrapy.utils.project import get_project_settings

from spiders.ikea_spider import IkeaSpider
from spiders.vivense_spider import VivenseSpider
from spiders.istikbal_spider import IstikbalSpider


SPIDERS = {
    "ikea": IkeaSpider,
    "vivense": VivenseSpider,
    "istikbal": IstikbalSpider,
}


def parse_args():
    parser = argparse.ArgumentParser(description="Run furniture crawlers.")
    parser.add_argument(
        "--spider",
        action="append",
        choices=sorted(SPIDERS),
        help="Spider to run. Can be repeated. Defaults to all spiders.",
    )
    parser.add_argument(
        "--target-per-category",
        type=int,
        default=None,
        help="Maximum number of products to scrape from each accepted category.",
    )
    parser.add_argument(
        "--until-finished",
        action="store_true",
        help="Ignore target limits and scrape each accepted category until it has no products/pages left.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    selected_spiders = args.spider or list(SPIDERS)

    print("Veri kazıma süreci başlatılıyor...")
    if args.until_finished:
        print("Mod: kabul edilen kategoriler bitene kadar kazı.")
    elif args.target_per_category:
        print(f"Mod: kategori başına {args.target_per_category} ürün.")
    else:
        print("Mod: kabul edilen kategoriler bitene kadar kazı.")

    settings = get_project_settings()
    process = CrawlerProcess(settings)

    for spider_name in selected_spiders:
        process.crawl(
            SPIDERS[spider_name],
            target_per_category=args.target_per_category,
            scrape_until_finished=args.until_finished or args.target_per_category is None,
        )

    process.start()
    print("Tüm veri kazıma işlemleri tamamlandı!")


if __name__ == "__main__":
    main()
