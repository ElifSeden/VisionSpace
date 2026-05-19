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

  /// Parse a product from the ai-service backend response.
  ///
  /// [polygon] is an optional list of coordinate pairs from the
  /// `clickable_regions` response. The center of the polygon is used
  /// to derive normalized [left] and [top] hotspot positions.
  /// [imageWidth] and [imageHeight] are the room image dimensions
  /// used for coordinate normalization.
  factory ProductSpot.fromBackendJson(
    Map<String, dynamic> json, {
    List<List<double>>? polygon,
    int imageWidth = 1,
    int imageHeight = 1,
    String Function(String path)? imageUrlBuilder,
  }) {
    final priceMap = json['price'] as Map<String, dynamic>?;
    final priceStr = priceMap != null
        ? '${(priceMap['amount'] as num?)?.toStringAsFixed(0) ?? '?'} ${priceMap['currency'] ?? 'TL'}'
        : '';

    double hotspotLeft = 0.5;
    double hotspotTop = 0.5;
    final safeImageWidth = imageWidth <= 0 ? 1 : imageWidth;
    final safeImageHeight = imageHeight <= 0 ? 1 : imageHeight;
    if (polygon != null && polygon.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final point in polygon) {
        sumX += point[0];
        sumY += point[1];
      }
      hotspotLeft = (sumX / polygon.length) / safeImageWidth;
      hotspotTop = (sumY / polygon.length) / safeImageHeight;
    }

    final rawScore = (json['score'] as num?)?.toDouble() ?? 0.0;
    final normalizedScore = rawScore <= 1 ? rawScore * 100 : rawScore;
    final imagePath = json['image_path'] as String? ?? '';

    return ProductSpot(
      id: json['product_id'] as String? ?? json['external_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['role'] as String? ?? json['category'] as String? ?? '',
      price: priceStr,
      matchScore: normalizedScore.round().clamp(0, 100).toInt(),
      left: hotspotLeft.clamp(0.0, 1.0),
      top: hotspotTop.clamp(0.0, 1.0),
      imageUrl: imageUrlBuilder != null && imagePath.isNotEmpty
          ? imageUrlBuilder(imagePath)
          : imagePath,
      buyUrl: json['source_url'] as String? ?? '',
      storeName: '',
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
