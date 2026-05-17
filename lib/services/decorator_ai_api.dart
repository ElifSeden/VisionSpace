import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/design_project.dart';
import '../models/product_spot.dart';

abstract class DecoratorAiApi {
  Future<List<DesignProject>> fetchProjects();
  Future<DesignProject> analyzeSpace({required String scanId});
}

class FirestoreDecoratorAiApi implements DecoratorAiApi {
  FirestoreDecoratorAiApi({
    FirebaseFirestore? firestore,
    DecoratorAiApi fallback = const MockDecoratorAiApi(),
  }) : _firestore = firestore ?? _defaultFirestore(),
       _fallback = fallback;

  final FirebaseFirestore? _firestore;
  final DecoratorAiApi _fallback;

  static FirebaseFirestore? _defaultFirestore() {
    if (Firebase.apps.isEmpty) return null;

    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );
  }

  @override
  Future<List<DesignProject>> fetchProjects() async {
    final firestore = _firestore;
    if (firestore == null) return _fallback.fetchProjects();

    try {
      final snapshot = await firestore
          .collection('designProjects')
          .where('isPublished', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      if (snapshot.docs.isEmpty) return _fallback.fetchProjects();

      final projects = <DesignProject>[];
      for (final doc in snapshot.docs) {
        final productsSnapshot = await doc.reference
            .collection('products')
            .orderBy('sortOrder')
            .get();
        final products = productsSnapshot.docs.map((productDoc) {
          return ProductSpot.fromMap(productDoc.id, productDoc.data());
        }).toList();

        projects.add(
          DesignProject.fromMap(doc.id, doc.data(), products: products),
        );
      }

      return projects;
    } on FirebaseException {
      return _fallback.fetchProjects();
    }
  }

  @override
  Future<DesignProject> analyzeSpace({required String scanId}) async {
    final firestore = _firestore;

    try {
      await firestore?.collection('scans').add({
        'localScanId': scanId,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // The AI analysis backend is not connected yet; keep the user flow alive.
    }

    return _fallback.analyzeSpace(scanId: scanId);
  }
}

class MockDecoratorAiApi implements DecoratorAiApi {
  const MockDecoratorAiApi();

  @override
  Future<List<DesignProject>> fetchProjects() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return [_livingRoom, _office];
  }

  @override
  Future<DesignProject> analyzeSpace({required String scanId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _livingRoom;
  }
}

const _livingRoom = DesignProject(
  id: 'room-001',
  title: 'Akdeniz salon dönüşümü',
  spaceType: 'Ev',
  style: 'Warm minimal',
  imageUrl:
      'https://images.unsplash.com/photo-1600210492486-724fe5c67fb0?auto=format&fit=crop&w=1200&q=80',
  products: [
    ProductSpot(
      id: 'p-01',
      name: 'Keten üçlü koltuk',
      brand: 'Benzer ürün',
      price: '24.999 TL',
      matchScore: 94,
      left: 0.30,
      top: 0.60,
      imageUrl:
          'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=800&q=80',
      buyUrl: 'https://www.ikea.com/tr/tr/',
    ),
    ProductSpot(
      id: 'p-02',
      name: 'Traverten sehpa',
      brand: 'Benzer ürün',
      price: '7.490 TL',
      matchScore: 89,
      left: 0.58,
      top: 0.72,
      imageUrl:
          'https://images.unsplash.com/photo-1532372320978-9d6e67a5ef0c?auto=format&fit=crop&w=800&q=80',
      buyUrl: 'https://www.vivense.com/',
    ),
    ProductSpot(
      id: 'p-03',
      name: 'Kavisli lambader',
      brand: 'Benzer ürün',
      price: '3.250 TL',
      matchScore: 86,
      left: 0.76,
      top: 0.42,
      imageUrl:
          'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=800&q=80',
      buyUrl: 'https://www.trendyol.com/',
    ),
  ],
);

const _office = DesignProject(
  id: 'room-002',
  title: 'Odaklı çalışma alanı',
  spaceType: 'Ofis',
  style: 'Soft industrial',
  imageUrl:
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80',
  products: [
    ProductSpot(
      id: 'p-04',
      name: 'Ahşap çalışma masası',
      brand: 'Benzer ürün',
      price: '12.750 TL',
      matchScore: 91,
      left: 0.48,
      top: 0.68,
      imageUrl:
          'https://images.unsplash.com/photo-1518455027359-f3f8164ba6bd?auto=format&fit=crop&w=800&q=80',
      buyUrl: 'https://www.hepsiburada.com/',
    ),
  ],
);
