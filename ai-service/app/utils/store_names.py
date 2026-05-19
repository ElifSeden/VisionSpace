def normalize_store_name_from_url(source_url: str | None) -> str:
    """Return a user-facing store name from a product source URL."""
    url = (source_url or "").lower()

    if "ikea" in url:
        return "IKEA"
    if "vivense" in url:
        return "Vivense"
    if "istikbal" in url:
        return "İstikbal"
    return "Mağaza"
