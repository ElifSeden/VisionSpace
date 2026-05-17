class FurnitureItem {
  const FurnitureItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.material,
    required this.style,
    required this.price,
    required this.imageUrl,
    this.sourceUrl = 'https://www.ikea.com/',
    this.storeName = 'IKEA',
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String material;
  final String style;
  final String price;
  final String imageUrl;
  final String sourceUrl;
  final String storeName;
  final bool isFavorite;
}
