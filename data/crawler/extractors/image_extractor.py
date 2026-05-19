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
    current_domain = response.url
    regex_matches = []
    
    if "ikea.com.tr" in current_domain:
        # IKEA Türkiye CDN formatı (webp desteği eklendi)
        # Örnek: https://cdn.ikea.com.tr/urunler/2000_2000/PE826620.jpg
        ikea_pattern = r'(https://cdn\.ikea\.com\.tr/[^"\'\s]+\.(?:jpg|jpeg|png|webp))'
        matches = re.findall(ikea_pattern, response.text, re.IGNORECASE)
        
        # IKEA'da mümkünse en yüksek çözünürlüğü (2000_2000) zorla
        for img in matches:
            high_res_img = img.replace('/500_500/', '/2000_2000/').replace('/800_800/', '/2000_2000/')
            regex_matches.append(high_res_img)

    elif "istikbal.com.tr" in current_domain:
        # İstikbal Medya formatı (Magento altyapısı)
        # Örnek: https://www.istikbal.com.tr/media/catalog/product/...
        istikbal_pattern = r'(https://(?:www\.)?istikbal\.com\.tr/[^"\'\s]+\.(?:jpg|jpeg|png|webp))'
        matches = re.findall(istikbal_pattern, response.text, re.IGNORECASE)
        
        # İstikbal'de sayfa içindeki menü ikonlarını veya alakasız logoları almamak için 
        # sadece URL'sinde 'product' veya 'gallery' geçenleri filtreleyelim:
        filtered_matches = [img for img in matches if 'product' in img.lower() or 'gallery' in img.lower()]
        
        # Eğer filtreleme sonucu boş dönerse (URL yapısı farklıysa), güvenlik önlemi olarak hepsini ekle
        if not filtered_matches:
             filtered_matches = matches
             
        regex_matches.extend(filtered_matches)

    elif "vivense.com" in current_domain:
        # Mevcut Vivense kuralınız
        vivense_pattern = r'(https://img\.vivense\.com/(?:1920x1280|original)/images/[^"\'\s]+\.(?:jpg|jpeg|png|webp))'
        matches = re.findall(vivense_pattern, response.text, re.IGNORECASE)
        regex_matches.extend(matches)

    # Bulunan regex sonuçlarını ana listeye ekle
    for img in regex_matches:
        if img not in image_urls:
            image_urls.append(img)
            
    # Remove duplicates and empty strings
    cleaned_urls = [url for url in image_urls if url]

    # Tekrarları sil ve SADECE İLK 2 FOTOĞRAFI AL
    unique_urls = list(dict.fromkeys(cleaned_urls))
    return unique_urls[:2]
    
    # Return unique URLs while preserving order
    #return list(dict.fromkeys(cleaned_urls))
