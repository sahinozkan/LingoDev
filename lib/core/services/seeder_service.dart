// TODO: Yükleme sonrası silinecek
// Bu servis yalnızca Firestore ilk veri yüklemesi (seeding) için kullanılır.
// Yükleme tamamlandıktan sonra bu dosyayı ve buna ait tüm import'ları silin.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/package_seeder.dart'; // TODO: Yükleme sonrası silinecek

/// Firestore seeding servisi.
///
/// [packages] listesindeki tüm paketleri ve kelimelerini Firestore'a
/// WriteBatch kullanarak toplu olarak yükler.
///
/// ── Neden WriteBatch? ────────────────────────────────────────────────────
/// Tek tek `set()` çağrısı yerine batch kullanmak:
///   • Ağ isteği sayısını dramatik biçimde azaltır.
///   • Atomik yazım garantisi sunar (hepsi ya yazılır ya da yazılmaz).
///   • Firestore maliyetini düşürür.
///
/// ── 500 Op Limiti ────────────────────────────────────────────────────────
/// Firestore, tek bir WriteBatch'te en fazla 500 işleme izin verir.
/// 56 paket × (1 paket dokümanı + 20 kelime) = 1176 işlem → 3 batch gerekir.
///
/// Bu servis, tüm işlemleri [_kMaxOpsPerBatch] sınırına göre otomatik
/// olarak parçalara (chunk) böler; her chunk tek bir batch commit'e karşılık gelir.
// TODO: Yükleme sonrası silinecek
class SeederService {
  SeederService._();

  static const int _kMaxOpsPerBatch = 499; // 500 limitinin biraz altında güvenli sınır

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// [packages] verisini Firestore'a yükler.
  ///
  /// Toplam yüklenen paket sayısını döndürür.
  /// Herhangi bir hata olursa exception fırlatır.
  // TODO: Yükleme sonrası silinecek
  static Future<int> seedAll() async {
    if (packages.isEmpty) {
      throw StateError(
        'packages listesi boş. '
        'lib/core/data/package_seeder.dart dosyasına verilerinizi ekleyin.',
      );
    }

    // Tüm batch işlemlerini bir listeye topla
    final List<_BatchOp> ops = _buildOperations();

    // İşlemleri chunk'lara böl ve sırayla commit et
    await _commitInChunks(ops);

    return packages.length;
  }

  // ── Yardımcı: tüm Firestore yazma işlemlerini oluştur ──────────────────

  static List<_BatchOp> _buildOperations() {
    final ops = <_BatchOp>[];
    final now = Timestamp.now();

    for (final pkg in packages) {
      // 1. Paket dokümanı referansı (auto-id)
      final pkgRef = _db.collection('packages').doc();

      // 2. Paket yazma işlemi
      ops.add(
        _BatchOp(
          ref: pkgRef,
          data: {
            'title': pkg['title'] as String,
            'category': pkg['category'] as String,
            'level': pkg['level'] as String,
            'description': pkg['description'] as String,
            'createdAt': now,
          },
        ),
      );

      // 3. Bu pakete ait kelime yazma işlemleri
      final words = pkg['words'] as List<dynamic>? ?? [];
      for (final w in words) {
        final word = w as Map<String, dynamic>;
        final wordRef = pkgRef.collection('words').doc();

        // ⚠️  masteryLevel ve nextReviewAt EKLENMEZ
        ops.add(
          _BatchOp(
            ref: wordRef,
            data: {
              'english': word['english'] as String,
              'turkish': word['turkish'] as String,
              'synonyms': List<String>.from(
                word['synonyms'] as List? ?? const [],
              ),
              'antonyms': List<String>.from(
                word['antonyms'] as List? ?? const [],
              ),
              'partOfSpeech': (word['partOfSpeech'] as String?) ?? '',
              'exampleSentence': (word['exampleSentence'] as String?) ?? '',
              'createdAt': now,
            },
          ),
        );
      }
    }

    return ops;
  }

  // ── Yardımcı: ops listesini chunk'lara böl ve her birini commit et ──────

  static Future<void> _commitInChunks(List<_BatchOp> ops) async {
    int start = 0;

    while (start < ops.length) {
      final end = (start + _kMaxOpsPerBatch).clamp(0, ops.length);
      final chunk = ops.sublist(start, end);

      final batch = _db.batch();
      for (final op in chunk) {
        batch.set(op.ref, op.data);
      }

      await batch.commit();
      start = end;
    }
  }
}

/// Dahili yardımcı: tek bir Firestore yazma işlemini temsil eder.
class _BatchOp {
  const _BatchOp({required this.ref, required this.data});
  final DocumentReference ref;
  final Map<String, dynamic> data;
}
