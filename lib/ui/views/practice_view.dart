import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';

/// Aralıklı tekrar (Spaced Repetition) kelime pratik ekranı.
///
/// ── Mimari Notlar ────────────────────────────────────────────────────────────
/// 1. Kelimeleri Çekme: Sadece `nextReviewAt <= Timestamp.now()` olan kelimeler
///    oturum başında bir defa çekilir ve liste State içinde saklanır.
/// 2. Flashcard UI: Tek kart üzerinde 3D Flip (çevirme) animasyonu ile İngilizce
///    kelime ve cevap (Türkçe anlam, örnek cümle, eş/zıt anlamlar) sunulur.
/// 3. Puanlama Algoritması: Bildim (+1 level, +2/+4/+7/+14 gün, level 5 = mezun),
///    Bilemedim (-1 level, +1 gün ertesi gün tekrar).
/// 4. Tebrik Ekranı: Kelime kalmadığında şık bir tamamlama ekranı gösterilir.
class PracticeView extends StatefulWidget {
  const PracticeView({super.key});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView>
    with SingleTickerProviderStateMixin {
  late final WordRepository _wordRepo;
  late final Future<List<WordModel>> _dueWordsFuture;

  List<WordModel> _words = const [];
  int _currentIndex = 0;
  bool _answerRevealed = false;
  bool _isSubmitting = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _wordRepo = WordRepository(userId: uid);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _dueWordsFuture = _loadDueWords();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<List<WordModel>> _loadDueWords() async {
    final words = await _wordRepo.getDueWords();
    if (mounted) {
      setState(() {
        _words = words;
      });
    }
    return words;
  }

  void _toggleReveal() {
    if (_isSubmitting) return;
    if (_answerRevealed) {
      _flipController.reverse();
      setState(() => _answerRevealed = false);
    } else {
      _flipController.forward();
      setState(() => _answerRevealed = true);
    }
  }

  Future<void> _submit(bool correct) async {
    if (_isSubmitting || _currentIndex >= _words.length) return;
    setState(() => _isSubmitting = true);

    final word = _words[_currentIndex];
    try {
      await _wordRepo.submitAnswer(word.id, word.masteryLevel, correct);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İlerleme kaydedilirken hata oluştu: $e',
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

    if (!mounted) return;

    // Kartı bir sonraki kelime için sıfırla
    _flipController.reset();
    setState(() {
      _isSubmitting = false;
      _answerRevealed = false;
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
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
          'Kelime Pratiği',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder<List<WordModel>>(
        future: _dueWordsFuture,
        builder: (context, snapshot) {
          // ── 1. Yükleniyor ──────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          // ── 2. Hata ────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                      'Kelimeler yüklenirken bir hata oluştu',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Tekrar Dene',
                      icon: Icons.refresh_rounded,
                      onPressed: () {
                        setState(() {
                          _dueWordsFuture = _loadDueWords();
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // ── 3. Tamamlandı veya Tekrar Edilecek Kelime Yok ──────────────────
          if (_words.isEmpty || _currentIndex >= _words.length) {
            return _CompletionView(onDone: () => Navigator.pop(context));
          }

          final currentWord = _words[_currentIndex];

          // ── 4. Flashcard Pratik Oturumu ─────────────────────────────────────
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // İlerleme çubuğu ve Sayaç
                  _ProgressHeader(
                    current: _currentIndex + 1,
                    total: _words.length,
                  ),
                  const SizedBox(height: 20),

                  // 3D Çevrilebilir Flashcard
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleReveal,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          final angle = _flipAnimation.value * math.pi;
                          final isFront = angle < (math.pi / 2);

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // 3D Perspektif
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isFront
                                ? _CardFront(
                                    word: currentWord,
                                    onReveal: _toggleReveal,
                                  )
                                : Transform(
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi), // Aynalama düzeltmesi
                                    alignment: Alignment.center,
                                    child: _CardBack(
                                      word: currentWord,
                                      onFlipBack: _toggleReveal,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Alt Butonlar
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: !_answerRevealed
                        ? AppButton(
                            key: const ValueKey('reveal_btn'),
                            text: 'Cevabı Gör',
                            icon: Icons.visibility_rounded,
                            isOutlined: false,
                            onPressed: _toggleReveal,
                          )
                        : _AnswerActionButtons(
                            key: const ValueKey('answer_btns'),
                            isSubmitting: _isSubmitting,
                            onDontKnow: () => _submit(false),
                            onKnow: () => _submit(true),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: İlerleme Başlığı (Progress Header)
// ══════════════════════════════════════════════════════════════════════════════

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : current / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kelime $current / $total',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '%${(progress * 100).toInt()}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.surfaceLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Flashcard Ön Yüz (İngilizce + Part of Speech)
// ══════════════════════════════════════════════════════════════════════════════

class _CardFront extends StatelessWidget {
  const _CardFront({required this.word, required this.onReveal});

  final WordModel word;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Üst Seviye Göstergesi
          _MasteryDots(level: word.masteryLevel),
          const Spacer(),

          // Part of Speech Rozeti (Varsa)
          if (word.partOfSpeech.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                word.partOfSpeech.toLowerCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // İngilizce Kelime
          Text(
            word.english,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          const Spacer(),

          // Kart Çevirme İpucu
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 16,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                'Cevabı görmek için karta dokun',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Flashcard Arka Yüz (Türkçe + Örnek Cümle + Eş/Zıt Anlamlar)
// ══════════════════════════════════════════════════════════════════════════════

class _CardBack extends StatelessWidget {
  const _CardBack({required this.word, required this.onFlipBack});

  final WordModel word;
  final VoidCallback onFlipBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Üst Bar: İngilizce Kelime + Kartı Geri Çevir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    word.english,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _MasteryDots(level: word.masteryLevel),
              ],
            ),

            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: AppColors.surfaceLight.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 18),

            // Türkçe Karşılık
            Text(
              'TÜRKÇE ANLAMI',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              word.turkish,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryLight,
              ),
            ),

            // Örnek Cümle (Varsa)
            if (word.exampleSentence.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.surfaceLight,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Örnek Cümle',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${word.exampleSentence}"',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Eş Anlamlılar
            if (word.synonyms.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ChipList(
                title: 'Eş Anlamlılar',
                items: word.synonyms,
                color: AppColors.primaryLight,
              ),
            ],

            // Zıt Anlamlılar
            if (word.antonyms.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ChipList(
                title: 'Zıt Anlamlılar',
                items: word.antonyms,
                color: AppColors.textSecondary,
              ),
            ],

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Cevap Butonları (Bilemedim / Bildim)
// ══════════════════════════════════════════════════════════════════════════════

class _AnswerActionButtons extends StatelessWidget {
  const _AnswerActionButtons({
    super.key,
    required this.isSubmitting,
    required this.onDontKnow,
    required this.onKnow,
  });

  final bool isSubmitting;
  final VoidCallback onDontKnow;
  final VoidCallback onKnow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Bilemedim Butonu (Kırmızı / Hata Tonu)
        Expanded(
          child: _ActionButton(
            text: 'Bilemedim',
            icon: Icons.close_rounded,
            color: AppColors.error,
            backgroundColor: AppColors.error.withValues(alpha: 0.15),
            borderColor: AppColors.error.withValues(alpha: 0.6),
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onDontKnow,
          ),
        ),
        const SizedBox(width: 14),

        // Bildim Butonu (Yeşil / Başarı Tonu)
        Expanded(
          child: _ActionButton(
            text: 'Bildim',
            icon: Icons.check_rounded,
            color: Colors.white,
            backgroundColor: AppColors.success,
            borderColor: AppColors.success,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onKnow,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.isLoading,
    this.onPressed,
  });

  final String text;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.2),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Atom: Mastery Dots (Öğrenme Düzeyi Noktaları)
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
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
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
// Atom: Çip Listesi
// ══════════════════════════════════════════════════════════════════════════════

class _ChipList extends StatelessWidget {
  const _ChipList({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.textHint.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              child: Text(
                item,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Molecule: Tebrik ve Tamamlama Ekranı (Empty / Done State)
// ══════════════════════════════════════════════════════════════════════════════

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.celebration_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bugünlük tüm kelimeleri bitirdin, harikasın!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aralıklı tekrar seansını başarıyla tamamladın. Zamanı geldiğinde yeni kelimeler burada seni bekliyor olacak.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            AppButton(
              text: 'Ana Sayfaya Dön',
              icon: Icons.home_rounded,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}
