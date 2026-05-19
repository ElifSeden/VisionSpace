import argparse
import subprocess
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Run one Scrapy spider.")
    parser.add_argument("--spider", default="vivense", help="Spider name to run. Default: vivense.")
    parser.add_argument(
        "--target-per-category",
        type=int,
        default=None,
        help="Maximum number of products to scrape from each accepted category.",
    )
    parser.add_argument(
        "--until-finished",
        action="store_true",
        help="Ignore target limits and scrape each accepted category until finished.",
    )
    return parser.parse_args()


def run_spider():
    args = parse_args()
    project_dir = Path(__file__).resolve().parent / "crawler"
    command = ["scrapy", "crawl", args.spider]

    if args.until_finished or args.target_per_category is None:
        command.extend(["-a", "scrape_until_finished=true"])
    else:
        command.extend(["-a", f"target_per_category={args.target_per_category}"])

    print(f"Starting Scrapy spider {args.spider!r}...")
    try:
        subprocess.run(command, cwd=project_dir, check=True)
        print("Spider finished successfully.")
    except subprocess.CalledProcessError as exc:
        print(f"Spider failed with error: {exc}")


if __name__ == "__main__":
    run_spider()
