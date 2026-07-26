import 'package:cloud_firestore/cloud_firestore.dart';

/// Tek bir hazır paketin seed verisi: paket meta bilgisi + kelime listesi.
class _SeedPackage {
  const _SeedPackage({
    required this.id,
    required this.title,
    required this.category,
    required this.level,
    required this.description,
    required this.words,
  });

  final String id;
  final String title;
  final String category;
  final String level;
  final String description;
  final List<_SeedWord> words;
}

/// Paket içindeki tek bir kelime. masteryLevel/nextReviewAt İÇERMEZ —
/// bu alanlar kişiye özeldir ve yalnızca WordRepository.importWords()
/// kullanıcının kendi koleksiyonuna kopyalarken eklenir.
class _SeedWord {
  const _SeedWord({
    required this.english,
    required this.turkish,
    this.synonyms = const [],
    this.antonyms = const [],
  });

  final String english;
  final String turkish;
  final List<String> synonyms;
  final List<String> antonyms;
}

// ── Seed verisi ─────────────────────────────────────────────────────────────
// YENİ PAKET EKLEMEK İÇİN: bu listeye yeni bir `_SeedPackage(...)` girişi ekle.
// `id` sabit ve benzersiz olmalı (örn. "engineering", "football", "gaming",
// "business") — seedPackages() tekrar çalıştırıldığında aynı ID'nin üzerine yazar.
final List<_SeedPackage> _packages = [
  _SeedPackage(
    id: 'daily',
    title: 'Günlük Konuşma',
    category: 'general',
    level: 'A2',
    description: 'Günlük hayatta sık kullanılan temel İngilizce kelimeler.',
    words: const [
      _SeedWord(
        english: 'appointment',
        turkish: 'randevu',
        synonyms: ['meeting', 'engagement'],
      ),
      _SeedWord(
        english: 'grocery',
        turkish: 'market alışverişi',
        synonyms: ['shopping'],
      ),
      _SeedWord(
        english: 'exhausted',
        turkish: 'çok yorgun',
        synonyms: ['tired', 'drained'],
        antonyms: ['energetic', 'refreshed'],
      ),
    ],
  ),

  // Sıradaki paketler buraya eklenecek, örneğin:
  // _SeedPackage(
  //   id: 'engineering',
  //   title: 'Mühendislik',
  //   category: 'engineering',
  //   level: 'B2',
  //   description: '...',
  //   words: const [ _SeedWord(english: '...', turkish: '...'), ... ],
  // ),
  // _SeedPackage(id: 'football', ...),
  // _SeedPackage(id: 'gaming', ...),
  // _SeedPackage(id: 'business', ...),
];

/// Hazır paketleri ve kelimelerini `packages/{packageId}` altına yazar.
///
/// `packageId` sabit olduğu için birden fazla kez çağrılsa da aynı paketin
/// üzerine yazar, mükerrer paket oluşturmaz. Kelime döküman ID'leri Firestore
/// tarafından otomatik üretildiği için, aynı paket tekrar yazılmadan önce
/// mevcut `words` alt-koleksiyonu tamamen SİLİNİR — aksi halde her çağrıda
/// kelimeler mükerrer birikir.
Future<void> seedPackages() async {
  final firestore = FirebaseFirestore.instance;

  for (final package in _packages) {
    final packageRef = firestore.collection('packages').doc(package.id);

    await packageRef.set({
      'title': package.title,
      'category': package.category,
      'level': package.level,
      'description': package.description,
      'createdAt': Timestamp.now(),
    });

    final wordsRef = packageRef.collection('words');

    final existingWords = await wordsRef.get();
    if (existingWords.docs.isNotEmpty) {
      final deleteBatch = firestore.batch();
      for (final doc in existingWords.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final writeBatch = firestore.batch();
    final now = Timestamp.now();
    for (final word in package.words) {
      writeBatch.set(wordsRef.doc(), {
        'english': word.english,
        'turkish': word.turkish,
        'synonyms': List<String>.from(word.synonyms),
        'antonyms': List<String>.from(word.antonyms),
        'createdAt': now,
      });
    }
    await writeBatch.commit();
  }
}
