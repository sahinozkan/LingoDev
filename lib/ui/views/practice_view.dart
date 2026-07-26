import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';

/// Aralıklı tekrar (spaced repetition) pratik ekranı.
/// Session başında bugün tekrar edilmesi gereken kelimeleri bir kez çeker,
/// kullanıcı "Bildim / Bilemedim" seçtikçe kelimenin mastery seviyesini günceller.
class PracticeView extends StatefulWidget {
  const PracticeView({super.key});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  late final WordRepository _wordRepo;
  late final Future<List<WordModel>> _dueWordsFuture;

  List<WordModel> _words = const [];
  int _currentIndex = 0;
  bool _answerRevealed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _wordRepo = WordRepository(userId: uid);
    _dueWordsFuture = _wordRepo.getDueWords().then((words) {
      _words = words;
      return words;
    });
  }

  Future<void> _submit(bool correct) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final word = _words[_currentIndex];
    try {
      await _wordRepo.submitAnswer(word.id, word.masteryLevel, correct);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hata: $e',
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pratik',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: FutureBuilder<List<WordModel>>(
        future: _dueWordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Bir hata oluştu',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
            );
          }

          if (_words.isEmpty || _currentIndex >= _words.length) {
            return _CompletionView(onDone: () => Navigator.pop(context));
          }

          final word = _words[_currentIndex];
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ProgressHeader(
                    current: _currentIndex + 1,
                    total: _words.length,
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _PracticeCard(
                      word: word,
                      revealed: _answerRevealed,
                      onReveal: () => setState(() => _answerRevealed = true),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AnswerButtons(
                    enabled: _answerRevealed && !_isSubmitting,
                    onDontKnow: () => _submit(false),
                    onKnow: () => _submit(true),
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

// ── Sub-widgets ────────────────────────────────────────────────────────────

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
        Text(
          '$current / $total',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.textHint.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.word,
    required this.revealed,
    required this.onReveal,
  });

  final WordModel word;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Text(
              word.english,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            if (!revealed)
              AppButton(
                text: 'Cevabı Gör',
                icon: Icons.visibility_rounded,
                isOutlined: true,
                onPressed: onReveal,
              )
            else ...[
              Container(
                height: 1,
                color: AppColors.textHint.withOpacity(0.15),
              ),
              const SizedBox(height: 20),
              Text(
                word.turkish,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (word.synonyms.isNotEmpty) ...[
                const SizedBox(height: 20),
                _BadgeSection(label: 'Eş Anlamlılar', items: word.synonyms),
              ],
              if (word.antonyms.isNotEmpty) ...[
                const SizedBox(height: 16),
                _BadgeSection(label: 'Zıt Anlamlılar', items: word.antonyms),
              ],
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) => _Badge(label: item)).toList(),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({
    required this.enabled,
    required this.onDontKnow,
    required this.onKnow,
  });

  final bool enabled;
  final VoidCallback onDontKnow;
  final VoidCallback onKnow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SolidButton(
            text: 'Bilemedim',
            color: AppColors.textHint,
            icon: Icons.close_rounded,
            onPressed: enabled ? onDontKnow : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            text: 'Bildim',
            icon: Icons.check_rounded,
            onPressed: enabled ? onKnow : null,
          ),
        ),
      ],
    );
  }
}

/// "Bilemedim" için AppButton'ın görünümüne uyan ama softGray (nötr) renkli buton.
class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.text,
    required this.color,
    required this.icon,
    this.onPressed,
  });

  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 10),
              Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
            const Icon(
              Icons.celebration_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Bugünlük tüm kelimeleri tekrar ettin 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
