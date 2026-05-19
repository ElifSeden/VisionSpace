import 'product_spot.dart';

class DesignProject {
  const DesignProject({
    required this.id,
    required this.title,
    required this.spaceType,
    required this.style,
    required this.imageUrl,
    required this.products,
  });

  final String id;
  final String title;
  final String spaceType;
  final String style;
  final String imageUrl;
  final List<ProductSpot> products;

  factory DesignProject.fromMap(
    String id,
    Map<String, dynamic> data, {
    List<ProductSpot> products = const <ProductSpot>[],
  }) {
    return DesignProject(
      id: id,
      title: data['title'] as String? ?? '',
      spaceType: data['spaceType'] as String? ?? '',
      style: data['style'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      products: products,
    );
  }

  /// Parse a single design from the ai-service backend response.
  ///
  /// Backend polygons are expected to be normalized 0.0-1.0 values. The image
  /// dimensions are still accepted so older pixel-coordinate responses map
  /// correctly while deployments roll forward.
  /// [roomImageUrl] is the original uploaded room image URL.
  factory DesignProject.fromBackendJson(
    Map<String, dynamic> json, {
    int imageWidth = 1,
    int imageHeight = 1,
    String roomImageUrl = '',
    String Function(String path)? imageUrlBuilder,
  }) {
    final rawProducts = json['products'] as List<dynamic>? ?? [];
    final rawRegions = json['clickable_regions'] as List<dynamic>? ?? [];

    // Build a map of product_id -> normalized placement polygon for hotspots.
    final polygonsByProductId = <String, List<List<double>>>{};
    for (final region in rawRegions) {
      final r = region as Map<String, dynamic>;
      final pid = r['product_id'] as String? ?? '';
      final rawPolygon = r['polygon'] as List<dynamic>? ?? [];
      final polygon = rawPolygon
          .map(
            (p) =>
                (p as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
          )
          .toList();
      if (pid.isNotEmpty && polygon.isNotEmpty) {
        polygonsByProductId[pid] = polygon;
      }
    }

    final products = rawProducts.map((p) {
      final productJson = p as Map<String, dynamic>;
      final productId = productJson['product_id'] as String? ?? '';
      return ProductSpot.fromBackendJson(
        productJson,
        polygon: polygonsByProductId[productId],
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        imageUrlBuilder: imageUrlBuilder,
      );
    }).toList();

    final image = json['image'] as Map<String, dynamic>?;
    final generatedImagePath = image?['path'] as String?;
    final designImageUrl =
        generatedImagePath != null &&
            generatedImagePath.isNotEmpty &&
            imageUrlBuilder != null
        ? imageUrlBuilder(generatedImagePath)
        : roomImageUrl;

    return DesignProject(
      id: json['design_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      spaceType: '',
      style: json['style'] as String? ?? '',
      imageUrl: designImageUrl,
      products: products,
    );
  }

  Map<String, dynamic> toMap({int? sortOrder, bool isPublished = true}) {
    return {
      'title': title,
      'spaceType': spaceType,
      'style': style,
      'imageUrl': imageUrl,
      'isPublished': isPublished,
      'sortOrder': ?sortOrder,
    };
  }
}
