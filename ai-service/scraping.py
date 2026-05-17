import asyncio
import os
import json
import subprocess

def run_spider():
    """
    Runs the Scrapy spider as a subprocess and blocks until it finishes.
    This replaces the previous Playwright scraping logic.
    """
    print("Starting Scrapy spider 'vivense' (crawling ALL products)...")
    project_dir = os.path.join(os.path.dirname(__file__), "furniture-crawler")
    
    # Removed CLOSESPIDER_ITEMCOUNT to crawl all products
    command = ["scrapy", "crawl", "vivense"]
    
    try:
        subprocess.run(command, cwd=project_dir, check=True)
        print("Spider finished successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Spider failed with error: {e}")

if __name__ == "__main__":
    run_spider()
