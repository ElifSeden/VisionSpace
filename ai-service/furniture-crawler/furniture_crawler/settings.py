import os

BOT_NAME = "furniture_crawler"

SPIDER_MODULES = ["furniture_crawler.spiders"]
NEWSPIDER_MODULE = "furniture_crawler.spiders"

# Obey robots.txt rules - set to False to ensure we can scrape
ROBOTSTXT_OBEY = False

# Configure item pipelines
ITEM_PIPELINES = {
    "furniture_crawler.pipelines.FurnitureImagePipeline": 1,
    "furniture_crawler.pipelines.JsonExportPipeline": 2,
}

# Image Pipeline settings
IMAGES_STORE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "output", "images")

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
