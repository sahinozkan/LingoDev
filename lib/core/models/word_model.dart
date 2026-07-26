import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a vocabulary word stored in Firestore.
///
/// Firestore path: `users/{uid}/words/{wordId}`
class WordModel {
  /// The Firestore document ID. Always populated when read from Firestore.
  final String id;

  /// The English word or phrase.
  final String english;

  /// The Turkish translation.
  final String turkish;

  /// Synonyms of the word (same language).
  final List<String> synonyms;

  /// Antonyms of the word (same language).
  final List<String> antonyms;

  /// Spaced-repetition mastery level.
  ///
  /// Range: 0 (brand new) – 5 (fully mastered).
  final int masteryLevel;

  /// UTC timestamp of the next scheduled review session.
  ///
  /// `null` once [masteryLevel] reaches 5 ("mastered") — the word is then
  /// excluded from due-word queries.
  final DateTime? nextReviewAt;

  /// UTC timestamp of when the word was first added.
  final DateTime createdAt;

  const WordModel({
    required this.id,
    required this.english,
    required this.turkish,
    this.synonyms = const [],
    this.antonyms = const [],
    this.masteryLevel = 0,
    this.nextReviewAt,
    required this.createdAt,
  }) : assert(
          masteryLevel >= 0 && masteryLevel <= 5,
          'masteryLevel must be between 0 and 5',
        );

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [WordModel] from a raw Firestore [DocumentSnapshot].
  ///
  /// Firestore [Timestamp] fields (`nextReviewAt`, `createdAt`) are
  /// automatically converted to [DateTime].
  factory WordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? const {};

    return WordModel(
      id: doc.id,
      english: data['english'] as String? ?? '',
      turkish: data['turkish'] as String? ?? '',
      synonyms: (data['synonyms'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      antonyms: (data['antonyms'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      masteryLevel: ((data['masteryLevel'] as num?)?.toInt() ?? 0).clamp(0, 5),
      nextReviewAt: (data['nextReviewAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts this [WordModel] to a [Map] suitable for writing to Firestore.
  ///
  /// [DateTime] fields are converted back to Firestore [Timestamp].
  /// The document `id` is intentionally excluded — Firestore manages it.
  Map<String, dynamic> toFirestore() {
    return {
      'english': english,
      'turkish': turkish,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'masteryLevel': masteryLevel,
      'nextReviewAt':
          nextReviewAt != null ? Timestamp.fromDate(nextReviewAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ---------------------------------------------------------------------------
  // Immutable update
  // ---------------------------------------------------------------------------

  /// Returns a new [WordModel] with the specified fields replaced.
  ///
  /// If a parameter is omitted, the current value is preserved.
  WordModel copyWith({
    String? id,
    String? english,
    String? turkish,
    List<String>? synonyms,
    List<String>? antonyms,
    int? masteryLevel,
    DateTime? nextReviewAt,
    DateTime? createdAt,
  }) {
    return WordModel(
      id: id ?? this.id,
      english: english ?? this.english,
      turkish: turkish ?? this.turkish,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Object overrides
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    return 'WordModel('
        'id: $id, '
        'english: $english, '
        'turkish: $turkish, '
        'masteryLevel: $masteryLevel, '
        'nextReviewAt: $nextReviewAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
