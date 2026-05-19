import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


BOT_NAME = "crawler"

SPIDER_MODULES = ["spiders"]
NEWSPIDER_MODULE = "spiders"

# Obey robots.txt rules - set to False to ensure we can scrape
ROBOTSTXT_OBEY = False


ITEM_PIPELINES = {
    "pipelines.DuplicatesPipeline": 1,
    "pipelines.FurnitureImagePipeline": 2,
    "pipelines.JsonExportPipeline": 3,
}

# Configure item pipelines
"""
ITEM_PIPELINES = {
    "pipelines.FurnitureImagePipeline": 1,
    "pipelines.JsonExportPipeline": 2,
}
"""

# Image Pipeline settings
IMAGES_STORE = os.path.join(PROJECT_ROOT, "output", "images")

# Minimum width and height for images to download (ignore small icons/thumbnails if needed)
IMAGES_MIN_HEIGHT = 110
IMAGES_MIN_WIDTH = 110

# Set settings whose default value is deprecated to a future-proof value
REQUEST_FINGERPRINTER_IMPLEMENTATION = "2.7"
TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"
FEED_EXPORT_ENCODING = "utf-8"

# User Agent
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Add delay to avoid getting blocked
DOWNLOAD_DELAY = 0.5
CONCURRENT_REQUESTS_PER_DOMAIN = 4
