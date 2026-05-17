import re

def extract_image_urls(response, product_jsonld=None):
    """
    Attempts to extract ALL high-resolution image URLs from the product page.
    This uses multiple strategies (JSON-LD, meta tags, CSS selectors, and Regex).
    """
    image_urls = []
    
    # Strategy 1: Extract from JSON-LD if available
    if product_jsonld and 'image' in product_jsonld:
        images = product_jsonld['image']
        if isinstance(images, list):
            image_urls.extend(images)
        elif isinstance(images, str):
            image_urls.append(images)
            
    # Strategy 2: Look for Open Graph image
    og_image = response.xpath('//meta[@property="og:image"]/@content').get()
    if og_image and og_image not in image_urls:
        image_urls.append(og_image)
        
    # Strategy 3: Look for schema.org image
    schema_image = response.xpath('//meta[@itemprop="image"]/@content').get()
    if schema_image and schema_image not in image_urls:
        image_urls.append(schema_image)

    # Strategy 4: Fallback to common CSS selectors (might need adjustment per site)
    gallery_images = response.css('.product-image-gallery img::attr(src), .product-slider img::attr(data-original), .product-slider img::attr(src), img.lazy-product::attr(data-original)').getall()
    
    for img in gallery_images:
        if img and not img.startswith('data:image'):
            absolute_url = response.urljoin(img)
            if absolute_url not in image_urls:
                image_urls.append(absolute_url)
                
    # Strategy 5: Aggressive Regex for Vivense high-res images anywhere in the page body
    # This guarantees we get ALL images even if they are hidden in JS objects
    regex_matches = re.findall(r'(https://img\.vivense\.com/(?:1920x1280|original)/images/[^"\'\s]+\.(?:jpg|jpeg|png))', response.text, re.IGNORECASE)
    for img in regex_matches:
        if img not in image_urls:
            image_urls.append(img)
            
    # Remove duplicates and empty strings
    cleaned_urls = [url for url in image_urls if url]
    
    # Return unique URLs while preserving order
    return list(dict.fromkeys(cleaned_urls))
