import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/design_project.dart';
import '../models/product_spot.dart';
import 'ai_backend_client.dart';

abstract class DecoratorAiApi {
  Future<List<DesignProject>> fetchProjects();
  Future<DesignProject> analyzeSpace({required String scanId});

  /// Submit a room scan to the backend and poll until completion.
  ///
  /// [onProgress] is called with each poll result for stage updates.
  /// Returns the first completed design project or throws on failure.
  Future<DesignProject> submitAndPollScan({
    required File imageFile,
    ScanDesignOptions options = const ScanDesignOptions(),
    void Function(DesignJobResult)? onProgress,
  });
}

/// Real backend implementation using the ai-service REST API.
class BackendDecoratorAiApi implements DecoratorAiApi {
  BackendDecoratorAiApi({AiBackendClient? client})
    : _client = client ?? AiBackendClient();

  final AiBackendClient _client;

  @override
  Future<List<DesignProject>> fetchProjects() async {
    // Home feed still uses Firestore/mock data for curated projects.
    // Backend designs are created per-scan, not pre-curated.
    return const MockDecoratorAiApi().fetchProjects();
  }

  @override
  Future<DesignProject> analyzeSpace({required String scanId}) async {
    // Legacy method - use submitAndPollScan instead.
    return submitAndPollScan(imageFile: File(scanId));
  }

  @override
  Future<DesignProject> submitAndPollScan({
    required File imageFile,
    ScanDesignOptions options = const ScanDesignOptions(),
    void Function(DesignJobResult)? onProgress,
  }) async {
    // Step 1: Upload the room image
    final upload = await _client.uploadRoomImage(imageFile);

    // Step 2: Create the design job
    final jobId = await _client.createDesignJob(
      roomImagePath: upload.imagePath,
      options: options,
    );

    // Step 3: Poll until completion
    final result = await _client.pollDesignJob(jobId, onProgress: onProgress);

    if (result.isFailed) {
      throw BackendException(result.errorMessage ?? 'Design job failed');
    }

    if (result.designs.isEmpty) {
      throw const BackendException('No designs were generated');
    }

    // Map the first design to a DesignProject
    return DesignProject.fromBackendJson(
      result.designs.first,
      imageWidth: upload.width,
      imageHeight: upload.height,
      roomImageUrl: _client.imageUrl(upload.imagePath),
      imageUrlBuilder: _client.imageUrl,
    );
  }
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

  @override
  Future<DesignProject> submitAndPollScan({
    required File imageFile,
    ScanDesignOptions options = const ScanDesignOptions(),
    void Function(DesignJobResult)? onProgress,
  }) async {
    // Firestore API does not support the full backend flow; fallback to mock.
    return _fallback.submitAndPollScan(
      imageFile: imageFile,
      options: options,
      onProgress: onProgress,
    );
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

  @override
  Future<DesignProject> submitAndPollScan({
    required File imageFile,
    ScanDesignOptions options = const ScanDesignOptions(),
    void Function(DesignJobResult)? onProgress,
  }) async {
    // Simulate the full poll flow with stage updates.
    const stages = [
      'analyze_room',
      'create_design_strategies',
      'retrieve_candidates',
      'plan_placements',
      'persist_result',
    ];
    for (final stage in stages) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      onProgress?.call(
        DesignJobResult(
          jobId: 'mock-job',
          status: 'running',
          currentStage: stage,
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
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
