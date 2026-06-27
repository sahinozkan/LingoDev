import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/package_model.dart';

/// Repository for read operations on the public packages collection.
///
/// Firestore path: `packages/{packageId}`
class PackageRepository {
  PackageRepository()
      : _packagesCollection =
            FirebaseFirestore.instance.collection('packages');

  final CollectionReference<Map<String, dynamic>> _packagesCollection;

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  /// Real-time stream of all packages, ordered by [createdAt] descending.
  Stream<List<PackageModel>> watchPackages() {
    return _packagesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map(PackageModel.fromFirestore).toList();
          } catch (e) {
            print('PackageRepository error: $e');
            rethrow;
          }
        });
  }

  /// Fetches a single package by [packageId].
  ///
  /// Returns `null` if no document exists for the given ID.
  Future<PackageModel?> getPackage(String packageId) async {
    final doc = await _packagesCollection.doc(packageId).get();
    if (!doc.exists) return null;
    return PackageModel.fromFirestore(doc);
  }
}
