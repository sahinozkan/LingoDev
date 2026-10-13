import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';
import 'add_word_view.dart';
import 'word_detail_view.dart';

/// Kullanıcının kelime defterindeki tüm kelimeleri listeler, arar ve filtreler (Sprint 7).
///
/// ── Mimari Notlar ────────────────────────────────────────────────────────────
/// 1. Lokal Filtreleme Mantığı: Firestore'dan kelimeler tek seferlik çekilir,
///    [_allWords] listesinde tutulur ve arama/filtreleme in-memory olarak çalışır.
/// 2. Akıllı Sıfırlama: Kullanıcı arama çubuğuna yazdığında filtre çipi otomatik
///    olarak "Tümü" durumuna geçer; aktif filtre varsa tek tıkla temizleme sunulur.
/// 3. Navigasyon ve Senkronizasyon: Bir kelimeye tıklandığında [WordDetailView] açılır;
///    geri dönüldüğünde düzenleme veya silme işlemlerini yansıtmak için liste yenilenir.
class WordListView extends StatefulWidget {
  const WordListView({super.key});

  @override
  State<WordListView> createState() => _WordListViewState();
}

class _WordListViewState extends State<WordListView> {
  // ── State ────────────────────────────────────────────────────────────────────

  List<WordModel> _allWords = [];
  List<WordModel> _filteredWords = [];

  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _selectedFilter = 'Tümü';

  late final TextEditingController _searchController;
  late final WordRepository _wordRepo;

  static const List<String> _filters = [
    'Tümü',
    'Öğrenilenler (Seviye 5)',
    'Çalışılacaklar',
    'Yeni Eklenenler',
  ];

  // ── Akıllı Rozet ve Filtre Durumu ──────────────────────────────────────────

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedFilter != 'Tümü';

  String get _badgeText {
    if (_selectedFilter == 'Tümü') {
      return '${_filteredWords.length} kelime';
    }
    String shortFilter = _selectedFilter;
    if (_selectedFilter.startsWith('Öğrenilenler')) {
      shortFilter = 'Öğrenilenler';
    }
    return '${_filteredWords.length} kelime ($shortFilter)';
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _wordRepo = WordRepository(userId: uid);
    _loadWords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Veri Yükleme (Lokal Filtreleme İçin Tek Seferlik) ─────────────────────────

  Future<void> _loadWords() async {
    try {
      final list = await _wordRepo.watchWords().first;
      if (!mounted) return;
      setState(() {
        _allWords = list;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Akıllı Sıfırlama ve Lokal Filtreleme Mantığı ─────────────────────────────

  void _onSearchChanged(String val) {
    if (val.trim().isNotEmpty && _selectedFilter != 'Tümü') {
      _selectedFilter = 'Tümü';
    }
    _searchQuery = val;
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();

    setState(() {
      _filteredWords = _allWords.where((word) {
        // 1. Arama filtresi (İngilizce veya Türkçe)
        final matchesSearch = q.isEmpty ||
            word.english.toLowerCase().contains(q) ||
            word.turkish.toLowerCase().contains(q);

        // 2. Kategori / Durum filtresi
        bool matchesFilter = true;
        switch (_selectedFilter) {
          case 'Öğrenilenler (Seviye 5)':
            matchesFilter = word.masteryLevel >= 5;
            break;
          case 'Çalışılacaklar':
            // Seviye 5 olmamış ve tekrar vakti gelmiş kelimeler
            matchesFilter = word.masteryLevel < 5 &&
                (word.nextReviewAt == null || !word.nextReviewAt!.isAfter(now));
            break;
          case 'Yeni Eklenenler':
            matchesFilter = word.masteryLevel == 0;
            break;
          case 'Tümü':
          default:
            matchesFilter = true;
            break;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _searchQuery = '';
    _selectedFilter = 'Tümü';
    _applyFilters();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Kelimelerim',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        // Akıllı Sayaç Rozeti
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_badgeText),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedFilter != 'Tümü'
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFilter != 'Tümü'
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _badgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedFilter != 'Tümü'
                            ? AppColors.primaryLight
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadWords();
                  },
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: _loadWords,
                  child: Column(
                    children: [
                      // ── 1. Arama Çubuğu (Search Bar) ─────────────────────────
                      _SearchBar(
                        controller: _searchController,
                        hasActiveFilters: _hasActiveFilters,
                        onChanged: _onSearchChanged,
                        onClearAll: _resetFilters,
                      ),

                      // ── 2. Hızlı Filtre Çipleri (ChoiceChips) ────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              'FİLTRELER',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHint,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            if (_hasActiveFilters)
                              InkWell(
                                onTap: _resetFilters,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.restart_alt_rounded,
                                        size: 14,
                                        color: AppColors.primaryLight,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Filtreleri Temizle',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 38,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: _filters.map((filter) {
                              final isSelected = filter == _selectedFilter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    filter,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    _selectedFilter = filter;
                                    _applyFilters();
                                  },
                                  selectedColor: AppColors.primary,
                                  backgroundColor: AppColors.surface,
                                  showCheckmark: false,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceLight,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        color: AppColors.surfaceLight.withValues(alpha: 0.6),
                      ),

                      // ── 3. Kelime Listesi veya Boş Durum ─────────────────────
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _filteredWords.isEmpty
                              ? _EmptyState(
                                  hasFilters: _hasActiveFilters,
                                  hasAnyWords: _allWords.isNotEmpty,
                                  onReset: _resetFilters,
                                  onAddWord: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AddWordView(),
                                      ),
                                    );
                                    _loadWords();
                                  },
                                )
                              : ListView.builder(
                                  key: const ValueKey('word_list'),
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 24),
                                  itemCount: _filteredWords.length,
                                  itemBuilder: (ctx, i) {
                                    final word = _filteredWords[i];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _WordListItem(
                                        word: word,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  WordDetailView(word: word),
                                            ),
                                          );
                                          // Detay sayfasında silme veya düzenleme yapılmış olabilir
                                          _loadWords();
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Kelime Satırı Kartı (Word List Item)
// ══════════════════════════════════════════════════════════════════════════════

class _WordListItem extends StatelessWidget {
  const _WordListItem({required this.word, required this.onTap});

  final WordModel word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Sol Kısım: İngilizce & Türkçe & Part of Speech
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.english,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (word.partOfSpeech.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              word.partOfSpeech.toLowerCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.turkish,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Sağ Kısım: Mastery Dots ve İlerleme Göstergesi
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MasteryDots(level: word.masteryLevel),
                  const SizedBox(height: 4),
                  Text(
                    word.masteryLevel >= 5
                        ? 'Öğrenildi'
                        : 'Seviye ${word.masteryLevel}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: word.masteryLevel >= 5
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Arama Çubuğu
// ══════════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hasActiveFilters,
    required this.onChanged,
    required this.onClearAll,
  });

  final TextEditingController controller;
  final bool hasActiveFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Kelime ara (İngilizce veya Türkçe)...',
          hintStyle: GoogleFonts.poppins(
            color: AppColors.textHint,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textHint,
            size: 20,
          ),
          suffixIcon: hasActiveFilters
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.primaryLight,
                    size: 19,
                  ),
                  tooltip: 'Tüm filtreleri ve aramayı temizle',
                  onPressed: onClearAll,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.surfaceLight,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.surfaceLight,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Mastery Noktaları (Öğrenme Düzeyi)
// ══════════════════════════════════════════════════════════════════════════════

class _MasteryDots extends StatelessWidget {
  const _MasteryDots({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = i < level;
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (level >= 5 ? AppColors.success : AppColors.primary)
                : AppColors.textHint.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Boş Durum (Empty State)
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.hasAnyWords,
    required this.onReset,
    required this.onAddWord,
  });

  final bool hasFilters;
  final bool hasAnyWords;
  final VoidCallback onReset;
  final VoidCallback onAddWord;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceLight,
                  width: 2,
                ),
              ),
              child: Icon(
                hasAnyWords
                    ? Icons.search_off_rounded
                    : Icons.menu_book_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Henüz kelime bulunamadı',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyWords
                  ? 'Arama veya filtre kriterlerinize uyan bir kelime bulunamadı.'
                  : 'Kelime defterinizde henüz kayıtlı bir kelime yok. Yeni kelime ekleyerek başlayabilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            if (hasFilters)
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(
                  Icons.restart_alt_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Filtreleri Temizle',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else if (!hasAnyWords)
              AppButton(
                text: 'Yeni Kelime Ekle',
                icon: Icons.add_rounded,
                onPressed: onAddWord,
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Hata Durumu (Error View)
// ══════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Tekrar Dene',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
