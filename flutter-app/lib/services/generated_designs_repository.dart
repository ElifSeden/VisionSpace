import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/design_project.dart';
import '../models/product_spot.dart';

class GeneratedDesignsRepository {
  GeneratedDesignsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? _defaultFirestore();

  final FirebaseFirestore? _firestore;

  static FirebaseFirestore? _defaultFirestore() {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  Future<List<DesignProject>> fetchGeneratedDesigns() async {
    final firestore = _firestore;
    final user = _currentUser();
    if (firestore == null || user == null) return const <DesignProject>[];

    try {
      final snapshot = await firestore
          .collection('generatedDesigns')
          .where('ownerUid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final projects = <DesignProject>[];
      for (final doc in snapshot.docs) {
        projects.add(await _projectFromDocument(doc));
      }
      return projects;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Generated designs fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <DesignProject>[];
    }
  }

  Future<String?> saveGeneratedDesign(DesignProject project) async {
    final firestore = _firestore;
    final user = await _ensureUser();
    if (firestore == null || user == null || project.id.trim().isEmpty) {
      return null;
    }

    final doc = firestore.collection('generatedDesigns').doc(project.id.trim());

    try {
      final batch = firestore.batch();
      batch.set(doc, {
        'ownerUid': user.uid,
        'title': project.title,
        'spaceType': project.spaceType,
        'style': project.style,
        'imageUrl': project.imageUrl,
        'productCount': project.products.length,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (var index = 0; index < project.products.length; index += 1) {
        final product = project.products[index];
        batch.set(doc.collection('products').doc(product.id), {
          ...product.toMap(),
          'sortOrder': index,
        });
      }

      await batch.commit();
      return doc.id;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Generated design save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<DesignProject?> fetchGeneratedDesign(String designId) async {
    final firestore = _firestore;
    final user = _currentUser();
    if (firestore == null || user == null || designId.trim().isEmpty) {
      return null;
    }

    try {
      final doc = await firestore
          .collection('generatedDesigns')
          .doc(designId.trim())
          .get();
      final data = doc.data();
      if (!doc.exists || data == null || data['ownerUid'] != user.uid) {
        return null;
      }
      return _projectFromDocument(doc);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Generated design fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<DesignProject> _projectFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final productsSnapshot = await doc.reference
        .collection('products')
        .orderBy('sortOrder')
        .get();
    final products = productsSnapshot.docs.map((productDoc) {
      return ProductSpot.fromMap(productDoc.id, productDoc.data());
    }).toList();

    return DesignProject.fromMap(doc.id, doc.data() ?? {}, products: products);
  }

  User? _currentUser() {
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseAuth.instance.currentUser;
    } catch (error, stackTrace) {
      debugPrint('Generated design user lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  Future<User?> _ensureUser() async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) return auth.currentUser;
      final credential = await auth.signInAnonymously();
      return credential.user;
    } catch (error, stackTrace) {
      debugPrint('Generated design auth failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
