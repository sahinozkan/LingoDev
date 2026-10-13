import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/package_model.dart';
import '../../core/services/package_repository.dart';
import '../../core/theme/app_colors.dart';
import 'package_detail_view.dart';

/// Hazır kelime paketlerini listeler.
///
/// ── Mimari Notlar ────────────────────────────────────────────────────────────
/// 1. Maliyet Tasarrufu: Veriler tek seferlik [Future] ile çekilir ve
///    State içinde [_allPackages] olarak tutulur. Tüm arama/filtreleme in-memory yapılır.
/// 2. UX & Filter Blindness Koruması:
///    - AppBar'da seçili filtreler açıkça ("X paket (B2, health)") gösterilir.
///    - Kullanıcı arama çubuğuna yazdığında çipler otomatik "Tümü" olarak sıfırlanır.
///    - Arama çubuğunda ve filtre alanında tek tıkla "Filtreleri Temizle" butonu sunulur.
class PackageListView extends StatefulWidget {
  const PackageListView({super.key});

  @override
  State<PackageListView> createState() => _PackageListViewState();
}

class _PackageListViewState extends State<PackageListView> {
  // ── State ────────────────────────────────────────────────────────────────────

  List<PackageModel> _allPackages = [];
  List<PackageModel> _filtered = [];

  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String _selectedLevel = 'Tümü';
  String _selectedCategory = 'Tümü';

  late final TextEditingController _searchController;
  late final PackageRepository _repo;

  // ── Akıllı Filtre Durumu ─────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedLevel != 'Tümü' ||
      _selectedCategory != 'Tümü';

  String get _filterSummaryText {
    final activeFilters = <String>[];
    if (_selectedLevel != 'Tümü') activeFilters.add(_selectedLevel);
    if (_selectedCategory != 'Tümü') activeFilters.add(_selectedCategory);

    if (activeFilters.isEmpty) {
      return '${_filtered.length} paket';
    }
    return '${_filtered.length} paket (${activeFilters.join(', ')})';
  }

  // ── Dinamik Filtre Seçenekleri ──────────────────────────────────────────────

  List<String> get _levels {
    final levels = <String>{'Tümü'};
    const standardLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
    for (final l in standardLevels) {
      if (_allPackages.any((p) => p.level.toUpperCase() == l)) {
        levels.add(l);
      }
    }
    for (final p in _allPackages) {
      final lvl = p.level.trim().toUpperCase();
      if (lvl.isNotEmpty && !levels.contains(lvl)) {
        levels.add(lvl);
      }
    }
    return levels.length > 1 ? levels.toList() : ['Tümü', ...standardLevels];
  }

  List<String> get _categories {
    final categories = <String>{'Tümü'};
    for (final p in _allPackages) {
      final cat = p.category.trim();
      if (cat.isNotEmpty) {
        categories.add(cat);
      }
    }
    if (categories.length > 1) {
      return categories.toList();
    }
    return const [
      'Tümü',
      'general',
      'academic',
      'business',
      'technology',
      'travel',
      'food',
      'health',
      'science',
      'sports',
    ];
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _repo = PackageRepository();
    _loadPackages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Veri Yükleme (Maliyet Tasarrufu İçin Tek Seferlik) ────────────────────────

  Future<void> _loadPackages() async {
    try {
      final list = await _repo.watchPackages().first;
      if (!mounted) return;
      setState(() {
        _allPackages = list;
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

  // ── Akıllı Sıfırlama ve Lokal Filtreleme ─────────────────────────────────────

  /// Kullanıcı arama çubuğuna yazmaya başladığında, seçili filtre çiplerini
  /// otomatik olarak "Tümü" durumuna sıfırlar. Böylece çip kısıtlaması nedeniyle
  /// beklenmeyen sıfır sonuç çıkması (Filter Blindness) engellenir.
  void _onSearchChanged(String val) {
    if (val.trim().isNotEmpty &&
        (_selectedLevel != 'Tümü' || _selectedCategory != 'Tümü')) {
      _selectedLevel = 'Tümü';
      _selectedCategory = 'Tümü';
    }

    _searchQuery = val;
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();

    setState(() {
      _filtered = _allPackages.where((pkg) {
        final matchesSearch = q.isEmpty ||
            pkg.title.toLowerCase().contains(q) ||
            pkg.description.toLowerCase().contains(q);

        final matchesLevel = _selectedLevel == 'Tümü' ||
            pkg.level.trim().toUpperCase() == _selectedLevel.trim().toUpperCase();

        final matchesCategory = _selectedCategory == 'Tümü' ||
            pkg.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase();

        return matchesSearch && matchesLevel && matchesCategory;
      }).toList();
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _searchQuery = '';
    _selectedLevel = 'Tümü';
    _selectedCategory = 'Tümü';
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hazır Paketler',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        // ── 1. Akıllı Dinamik Rozet (Seçili Filtreleri Gösterir) ─────────────
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_filterSummaryText),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (_selectedLevel != 'Tümü' || _selectedCategory != 'Tümü')
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_selectedLevel != 'Tümü' || _selectedCategory != 'Tümü')
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _filterSummaryText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (_selectedLevel != 'Tümü' || _selectedCategory != 'Tümü')
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
              ? _ErrorState(
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _loadPackages();
                  },
                )
              : Column(
                  children: [
                    // ── 2. Arama Çubuğu (Clear All Butonlu) ───────────────────
                    _SearchBar(
                      controller: _searchController,
                      hasActiveFilters: _hasActiveFilters,
                      onChanged: _onSearchChanged,
                      onClearAll: _resetFilters,
                    ),

                    // ── Filtre Başlık & Temizle Çubuğu ───────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.restart_alt_rounded,
                                      size: 15,
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

                    // ── 3. Hızlı Filtre Çipleri (Seviyeler) ───────────────────
                    _FilterChipGroup(
                      title: 'Seviye',
                      options: _levels,
                      selected: _selectedLevel,
                      onSelect: (val) {
                        _selectedLevel = val;
                        _applyFilters();
                      },
                    ),

                    // ── 4. Hızlı Filtre Çipleri (Kategoriler) ─────────────────
                    _FilterChipGroup(
                      title: 'Kategori',
                      options: _categories,
                      selected: _selectedCategory,
                      onSelect: (val) {
                        _selectedCategory = val;
                        _applyFilters();
                      },
                    ),

                    const SizedBox(height: 6),
                    Divider(
                      height: 1,
                      color: AppColors.surfaceLight.withValues(alpha: 0.6),
                    ),

                    // ── 5. Liste veya Boş Durum ───────────────────────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _filtered.isEmpty
                            ? _EmptyState(
                                hasFilters: _hasActiveFilters,
                                onReset: _resetFilters,
                              )
                            : ListView.builder(
                                key: const ValueKey('list'),
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PackageCard(package: _filtered[i]),
                                ),
                              ),
                      ),
                    ),
                  ],
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
          hintText: 'Paket ara (örn: Günlük, Teknoloji, B2)...',
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
// Molecule: Yatay Kaydırılabilir ChoiceChip Grubu
// ══════════════════════════════════════════════════════════════════════════════

class _FilterChipGroup extends StatelessWidget {
  const _FilterChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: SizedBox(
        height: 38,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '$title:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              ...options.map((opt) {
                final isSelected = opt == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      opt,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => onSelect(opt),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Paket Kartı
// ══════════════════════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});

  final PackageModel package;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PackageDetailView(package: package),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      package.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                ],
              ),
              if (package.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  package.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (package.category.isNotEmpty) ...[
                    _Tag(label: package.category, isPrimary: true),
                    const SizedBox(width: 8),
                  ],
                  if (package.level.isNotEmpty)
                    _Tag(label: package.level, isPrimary: false),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Tag (Etiket)
// ══════════════════════════════════════════════════════════════════════════════

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    this.isPrimary = false,
  });

  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.textHint.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: isPrimary ? AppColors.primaryLight : AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Boş Durum (Empty State)
// ══════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasFilters,
    required this.onReset,
  });

  final bool hasFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('empty'),
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
              child: const Icon(
                Icons.search_off_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sonuç bulunamadı',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arama veya filtre kriterlerinize uyan paket bulunamadı.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 18),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Hata Durumu (Error State)
// ══════════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
