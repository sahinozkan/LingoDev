import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';

/// Kelime Detay, Düzenleme ve Silme Ekranı (Sprint 6).
///
/// ── Mimari Notlar ────────────────────────────────────────────────────────────
/// 1. Detay Gösterimi: İngilizce kelime, Türkçe karşılık, partOfSpeech rozeti,
///    örnek cümle ve eş/zıt anlamlılar şık kartlar içinde listelenir.
/// 2. Silme İşlemi: AppBar'daki çöp kutusu ikonu onay (AlertDialog) sonrası
///    kelimeyi Firestore'dan siler ve önceki ekrana dönerek SnackBar gösterir.
/// 3. Düzenleme İşlemi: Sağ alttaki FAB (kalem ikonu) ile açılan BottomSheet
///    üzerinden kelime alanları güncellenir, Firestore'a yazılır ve UI yenilenir.
class WordDetailView extends StatefulWidget {
  const WordDetailView({super.key, required this.word});

  final WordModel word;

  @override
  State<WordDetailView> createState() => _WordDetailViewState();
}

class _WordDetailViewState extends State<WordDetailView> {
  late WordModel _currentWord;
  late final WordRepository _wordRepo;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentWord = widget.word;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _wordRepo = WordRepository(userId: uid);
  }

  // ── Silme Onay Dialog'u ──────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.surfaceLight,
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Kelimeyi Sil',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          '"${_currentWord.english}" kelimesini silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textHint,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sil',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await _wordRepo.deleteWord(_currentWord.id);
      if (!mounted) return;

      Navigator.pop(context); // Detay ekranından çık
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '"${_currentWord.english}" silindi',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.surfaceLight, width: 1),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silme işlemi başarısız: $e',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ── Düzenleme Modal BottomSheet'i ───────────────────────────────────────────

  void _openEditModal() {
    final englishCtrl = TextEditingController(text: _currentWord.english);
    final turkishCtrl = TextEditingController(text: _currentWord.turkish);
    final posCtrl = TextEditingController(text: _currentWord.partOfSpeech);
    final exampleCtrl = TextEditingController(text: _currentWord.exampleSentence);
    final synonymsCtrl = TextEditingController(text: _currentWord.synonyms.join(', '));
    final antonymsCtrl = TextEditingController(text: _currentWord.antonyms.join(', '));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sürükleme Çubuğu
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kelimeyi Düzenle',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textHint,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // İngilizce Kelime Alanı
                    _EditTextField(
                      controller: englishCtrl,
                      label: 'İngilizce Kelime',
                      hint: 'örn: afford',
                    ),
                    const SizedBox(height: 12),

                    // Türkçe Anlamı Alanı
                    _EditTextField(
                      controller: turkishCtrl,
                      label: 'Türkçe Karşılığı',
                      hint: 'örn: gücü yetmek, parası yetmek',
                    ),
                    const SizedBox(height: 12),

                    // Kelime Türü Alanı
                    _EditTextField(
                      controller: posCtrl,
                      label: 'Kelime Türü (Part of Speech)',
                      hint: 'örn: verb, noun, adjective',
                    ),
                    const SizedBox(height: 12),

                    // Örnek Cümle Alanı
                    _EditTextField(
                      controller: exampleCtrl,
                      label: 'Örnek Cümle',
                      hint: 'örn: I cannot afford this laptop.',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Eş Anlamlılar Alanı
                    _EditTextField(
                      controller: synonymsCtrl,
                      label: 'Eş Anlamlılar (virgülle ayırın)',
                      hint: 'örn: bear, sustain, manage',
                    ),
                    const SizedBox(height: 12),

                    // Zıt Anlamlılar Alanı
                    _EditTextField(
                      controller: antonymsCtrl,
                      label: 'Zıt Anlamlılar (virgülle ayırın)',
                      hint: 'örn: reject, abandon',
                    ),
                    const SizedBox(height: 20),

                    // Kaydet Butonu
                    AppButton(
                      text: 'Değişiklikleri Kaydet',
                      icon: Icons.check_rounded,
                      isLoading: isSaving,
                      onPressed: isSaving
                          ? null
                          : () async {
                              final eng = englishCtrl.text.trim();
                              final tur = turkishCtrl.text.trim();
                              if (eng.isEmpty || tur.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'İngilizce ve Türkçe alanları boş bırakılamaz.',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              List<String> parseList(String raw) => raw
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();

                              final updatedWord = _currentWord.copyWith(
                                english: eng,
                                turkish: tur,
                                partOfSpeech: posCtrl.text.trim(),
                                exampleSentence: exampleCtrl.text.trim(),
                                synonyms: parseList(synonymsCtrl.text),
                                antonyms: parseList(antonymsCtrl.text),
                              );

                              try {
                                await _wordRepo.updateWord(updatedWord);
                                if (!mounted) return;

                                setState(() {
                                  _currentWord = updatedWord;
                                });

                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Kelime başarıyla güncellendi.',
                                        style: GoogleFonts.poppins(fontSize: 13),
                                      ),
                                      backgroundColor: AppColors.primaryDark,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSaving = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Güncelleme hatası: $err',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kelime Detayı',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Silme Butonu
          _isDeleting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                  tooltip: 'Kelimeyi Sil',
                  onPressed: _confirmDelete,
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: _openEditModal,
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        label: Text(
          'Düzenle',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero / Başlık Kartı ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Satır: Part of Speech + Öğrenme Noktaları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentWord.partOfSpeech.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _currentWord.partOfSpeech.toLowerCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      _MasteryLevelIndicator(level: _currentWord.masteryLevel),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // İngilizce Başlık
                  Text(
                    _currentWord.english,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Türkçe Karşılık
                  Text(
                    _currentWord.turkish,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── 2. Örnek Cümle Kartı (Varsa) ─────────────────────────────────
            if (_currentWord.exampleSentence.isNotEmpty) ...[
              _SectionTitle(title: 'ÖRNEK CÜMLE', icon: Icons.format_quote_rounded),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.surfaceLight,
                    width: 1,
                  ),
                ),
                child: Text(
                  '"${_currentWord.exampleSentence}"',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── 3. Eş Anlamlılar Kartı ───────────────────────────────────────
            _SectionTitle(title: 'EŞ ANLAMLILAR', icon: Icons.sync_alt_rounded),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.surfaceLight,
                  width: 1,
                ),
              ),
              child: _currentWord.synonyms.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentWord.synonyms
                          .map(
                            (s) => _ChipTag(
                              label: s,
                              color: AppColors.primaryLight,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            ),
                          )
                          .toList(),
                    )
                  : Text(
                      'Henüz eş anlamlı eklenmemiş.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // ── 4. Zıt Anlamlılar Kartı ──────────────────────────────────────
            _SectionTitle(title: 'ZIT ANLAMLILAR', icon: Icons.compare_arrows_rounded),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.surfaceLight,
                  width: 1,
                ),
              ),
              child: _currentWord.antonyms.isNotEmpty
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentWord.antonyms
                          .map(
                            (a) => _ChipTag(
                              label: a,
                              color: AppColors.textSecondary,
                              backgroundColor: AppColors.surfaceLight,
                            ),
                          )
                          .toList(),
                    )
                  : Text(
                      'Henüz zıt anlamlı eklenmemiş.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // ── 5. Spaced Repetition Durum Bilgisi ────────────────────────────
            _SectionTitle(title: 'ARALIKLI TEKRAR DURUMU', icon: Icons.schedule_rounded),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.surfaceLight,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Öğrenme Seviyesi:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _currentWord.masteryLevel >= 5
                            ? 'Tamamlandı (5/5) 🎉'
                            : 'Seviye ${_currentWord.masteryLevel} / 5',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _currentWord.masteryLevel >= 5
                              ? AppColors.success
                              : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sonraki Tekrar:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatNextReview(_currentWord.nextReviewAt),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNextReview(DateTime? date) {
    if (date == null) return 'Tamamlandı (Tekrar gerekmiyor)';
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) {
      return 'Şimdi hazır (Gecikmiş)';
    } else if (diff.inHours < 24) {
      return '${diff.inHours + 1} saat sonra';
    } else {
      return '${diff.inDays} gün sonra (${date.day}.${date.month}.${date.year})';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Bölüm Başlığı
// ══════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Çip Etiket
// ══════════════════════════════════════════════════════════════════════════════

class _ChipTag extends StatelessWidget {
  const _ChipTag({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Öğrenme Noktaları Göstergesi
// ══════════════════════════════════════════════════════════════════════════════

class _MasteryLevelIndicator extends StatelessWidget {
  const _MasteryLevelIndicator({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isFilled = i < level;
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? AppColors.primary
                : AppColors.textHint.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Düzenleme Formu TextField'ı
// ══════════════════════════════════════════════════════════════════════════════

class _EditTextField extends StatelessWidget {
  const _EditTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: AppColors.textHint,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
