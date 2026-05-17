class ProductSpot {
  const ProductSpot({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.matchScore,
    required this.left,
    required this.top,
    required this.imageUrl,
    required this.buyUrl,
    this.storeName = '',
  });

  final String id;
  final String name;
  final String brand;
  final String price;
  final int matchScore;
  final double left;
  final double top;
  final String imageUrl;
  final String buyUrl;
  final String storeName;

  factory ProductSpot.fromMap(String id, Map<String, dynamic> data) {
    return ProductSpot(
      id: id,
      name: data['name'] as String? ?? '',
      brand: data['brand'] as String? ?? '',
      price: data['price'] as String? ?? '',
      matchScore: (data['matchScore'] as num?)?.toInt() ?? 0,
      left: (data['left'] as num?)?.toDouble() ?? 0,
      top: (data['top'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
      buyUrl: data['buyUrl'] as String? ?? '',
      storeName: data['storeName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'price': price,
      'matchScore': matchScore,
      'left': left,
      'top': top,
      'imageUrl': imageUrl,
      'buyUrl': buyUrl,
      'storeName': storeName,
    };
  }
}
