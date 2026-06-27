import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a learning package stored in Firestore.
///
/// Firestore path: `packages/{packageId}`
class PackageModel {
  /// The Firestore document ID. Always populated when read from Firestore.
  final String id;

  /// The display title of the package.
  final String title;

  /// The category the package belongs to (e.g. "Grammar", "Business").
  final String category;

  /// The difficulty level of the package (e.g. "Beginner", "Intermediate").
  final String level;

  /// A short description of what the package covers.
  final String description;

  /// UTC timestamp of when the package was created.
  final DateTime createdAt;

  const PackageModel({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [PackageModel] from a raw Firestore [DocumentSnapshot].
  ///
  /// The Firestore [Timestamp] field (`createdAt`) is automatically converted
  /// to a [DateTime].
  factory PackageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PackageModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      level: data['level'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Converts this [PackageModel] to a [Map] suitable for writing to Firestore.
  ///
  /// The [DateTime] field is converted back to a Firestore [Timestamp].
  /// The document `id` is intentionally excluded — Firestore manages it.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'category': category,
      'level': level,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------------------------------------------------------------------
  // Immutable update
  // ---------------------------------------------------------------------------

  /// Returns a new [PackageModel] with the specified fields replaced.
  ///
  /// If a parameter is omitted, the current value is preserved.
  PackageModel copyWith({
    String? id,
    String? title,
    String? category,
    String? level,
    String? description,
    DateTime? createdAt,
  }) {
    return PackageModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      level: level ?? this.level,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Object overrides
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    return 'PackageModel('
        'id: $id, '
        'title: $title, '
        'category: $category, '
        'level: $level'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PackageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
