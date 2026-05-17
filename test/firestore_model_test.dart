import 'package:decorator_ai/models/design_project.dart';
import 'package:decorator_ai/models/product_spot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DesignProject parses Firestore map with products', () {
    final products = [
      ProductSpot.fromMap('p-01', {
        'name': 'Chair',
        'brand': 'Matched product',
        'price': '120 TL',
        'matchScore': 92,
        'left': 0.4,
        'top': 0.7,
        'imageUrl': 'https://example.com/chair.jpg',
        'buyUrl': 'https://example.com/chair',
      }),
    ];

    final project = DesignProject.fromMap('room-001', {
      'title': 'Living room',
      'spaceType': 'Home',
      'style': 'Warm minimal',
      'imageUrl': 'https://example.com/room.jpg',
    }, products: products);

    expect(project.id, 'room-001');
    expect(project.title, 'Living room');
    expect(project.products.single.id, 'p-01');
    expect(project.products.single.matchScore, 92);
  });

  test('ProductSpot serializes to Firestore map', () {
    const product = ProductSpot(
      id: 'p-02',
      name: 'Lamp',
      brand: 'Matched product',
      price: '80 TL',
      matchScore: 88,
      left: 0.25,
      top: 0.5,
      imageUrl: 'https://example.com/lamp.jpg',
      buyUrl: 'https://example.com/lamp',
      storeName: 'Example Store',
    );

    expect(product.toMap(), {
      'name': 'Lamp',
      'brand': 'Matched product',
      'price': '80 TL',
      'matchScore': 88,
      'left': 0.25,
      'top': 0.5,
      'imageUrl': 'https://example.com/lamp.jpg',
      'buyUrl': 'https://example.com/lamp',
      'storeName': 'Example Store',
    });
  });
}
