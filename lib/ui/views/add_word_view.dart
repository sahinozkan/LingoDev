import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';
import '../atoms/app_input.dart';

/// Kullanıcının Firestore koleksiyonuna yeni İngilizce kelime eklediği form ekranı.
class AddWordView extends StatefulWidget {
  const AddWordView({super.key});

  @override
  State<AddWordView> createState() => _AddWordViewState();
}

class _AddWordViewState extends State<AddWordView> {
  final _formKey = GlobalKey<FormState>();

  final _englishController = TextEditingController();
  final _turkishController = TextEditingController();
  final _synonymsController = TextEditingController();
  final _antonymsController = TextEditingController();

  /// Form kaydetme yükleme durumu
  bool _isLoading = false;

  /// Claude AI öneri isteği yükleme durumu
  bool _isAiLoading = false;

  /// 1 saniyelik debounce zamanlayıcısı
  Timer? _debounceTimer;

  // ── Anthropic Claude API sabitleri ───────────────────────────────────────
  static const String _anthropicApiKey =
      String.fromEnvironment('ANTHROPIC_KEY');
  static const String _anthropicEndpoint =
      'http://127.0.0.1:8080/api/claude';

  @override
  void initState() {
    super.initState();
    // İngilizce alanı dinle — 1 sn. debounce ile AI önerisi tetikle
    _englishController.addListener(_onEnglishChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _englishController.removeListener(_onEnglishChanged);
    _englishController.dispose();
    _turkishController.dispose();
    _synonymsController.dispose();
    _antonymsController.dispose();
    super.dispose();
  }

  // ── Debounce mantığı ─────────────────────────────────────────────────────

  /// İngilizce alan her değiştiğinde çalışır; 1 sn. sonra AI isteği atar.
  void _onEnglishChanged() {
    _debounceTimer?.cancel();
    final word = _englishController.text.trim();
    if (word.isEmpty) {
      if (_isAiLoading) setState(() => _isAiLoading = false);
      return;
    }
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _fetchAiSuggestion(word);
    });
  }

  // ── Anthropic Claude API isteği ──────────────────────────────────────────

  /// Verilen İngilizce kelime için Claude'dan Türkçe karşılık,
  /// eş anlamlı ve zıt anlamlı kelimeler ister, ardından alanları doldurur.
  Future<void> _fetchAiSuggestion(String word) async {
    if (!mounted) return;
    setState(() => _isAiLoading = true);

    try {
      final prompt =
          'For the English word \'$word\', provide Turkish translation, '
          '3 synonyms, 3 antonyms. Respond in JSON only, no markdown: '
          '{"turkish": "", "synonyms": "", "antonyms": ""}';

      final requestBody = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 200,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      });

      print('AI fetch started for: $word');

      final response = await http.post(
        Uri.parse(_anthropicEndpoint),
        headers: {
          'X-Api-Key': _anthropicApiKey,
          'content-type': 'application/json',
        },
        body: requestBody,
      );

      if (!mounted) return;

      print('AI response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;

        // Claude yanıt yapısını çöz: data['content'][0]['text']
        final contentList = decoded['content'] as List<dynamic>? ?? [];
        if (contentList.isEmpty) return;

        String rawText =
            (contentList.first['text'] as String? ?? '').trim();

        // ```json ... ``` veya ``` ... ``` bloğunu temizle
        rawText = rawText
            .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
            .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
            .replaceAll(RegExp(r'```$', multiLine: true), '')
            .trim();

        final parsed = jsonDecode(rawText) as Map<String, dynamic>;

        final turkish = parsed['turkish'] as String? ?? '';
        final synonyms = (parsed['synonyms'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(', ') ?? '';
        final antonyms = (parsed['antonyms'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .join(', ') ?? '';

        // Alanları doldur — sadece İngilizce alan listener tetikler,
        // bu alanlar tetiklemez, sonsuz döngü riski yok.
        _turkishController.text = turkish;
        _synonymsController.text = synonyms;
        _antonymsController.text = antonyms;

        // Başarı bildirimi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'AI önerisi uygulandı!',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // API hatası — sessizce geç, kullanıcı manuel doldurabilir
        debugPrint('Claude API hatası: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('AI öneri hatası: $e');
    } finally {
      if (mounted) setState(() => _isAiLoading = false);
    }
  }

  // ── Formu işle ve Firestore'a gönder ───────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Virgülle ayrılmış listeyi parse et
      List<String> parseList(String raw) => raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final now = DateTime.now();
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final word = WordModel(
        id: '',
        english: _englishController.text.trim(),
        turkish: _turkishController.text.trim(),
        synonyms: parseList(_synonymsController.text),
        antonyms: parseList(_antonymsController.text),
        masteryLevel: 0,
        createdAt: now,
        nextReviewAt: now,
      );

      final added = await WordRepository(userId: uid).addWord(word);

      if (!mounted) return;

      if (added) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bu kelime zaten listende',
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Yeni Kelime Ekle',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      // AppBar'ın altına ince lila çizgi
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Başlık kartı ──────────────────────────────────────────────
              _buildHeaderCard(),
              const SizedBox(height: 32),

              // ── Zorunlu alanlar ───────────────────────────────────────────
              _buildSectionLabel('Zorunlu Alanlar', Icons.star_rounded),
              const SizedBox(height: 16),

              // İngilizce alan — AI yükleniyor ise suffix spinner göster
              AppInput(
                hintText: 'Örn: endeavor',
                labelText: 'İngilizce Kelime',
                controller: _englishController,
                prefixIcon: Icons.translate_rounded,
                autofocus: true,
                suffixIcon: _isAiLoading ? _buildAiLoadingIndicator() : null,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bu alan zorunludur' : null,
              ),

              // AI ipucu metni
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isAiLoading
                    ? Padding(
                        key: const ValueKey('ai-hint'),
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 12,
                                color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'AI öneri hazırlanıyor…',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(key: ValueKey('ai-hint-empty')),
              ),
              const SizedBox(height: 16),

              AppInput(
                hintText: 'Örn: çaba göstermek',
                labelText: 'Türkçe Karşılığı',
                controller: _turkishController,
                prefixIcon: Icons.flag_rounded,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bu alan zorunludur' : null,
              ),
              const SizedBox(height: 32),

              // ── Opsiyonel alanlar ─────────────────────────────────────────
              _buildSectionLabel('Opsiyonel Alanlar', Icons.auto_awesome_rounded),
              const SizedBox(height: 8),
              Text(
                'Birden fazla değer için virgülle ayırın.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 16),

              AppInput(
                hintText: 'agree, accept, approve',
                labelText: 'Eş Anlamlılar (Synonyms)',
                controller: _synonymsController,
                prefixIcon: Icons.compare_arrows_rounded,
              ),
              const SizedBox(height: 16),

              AppInput(
                hintText: 'disagree, refuse',
                labelText: 'Zıt Anlamlılar (Antonyms)',
                controller: _antonymsController,
                prefixIcon: Icons.swap_horiz_rounded,
              ),
              const SizedBox(height: 40),

              // ── Gönder butonu ─────────────────────────────────────────────
              AppButton(
                text: 'Kelime Ekle',
                icon: Icons.add_circle_outline_rounded,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _submit,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// İngilizce alanının sağında görünen küçük lila spinner
  Widget _buildAiLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            AppColors.primary.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  /// Ekranın üstündeki dekoratif bilgi kartı
  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.book_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelime Kütüphaneni Genişlet',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yeni kelimeler aralıklı tekrar sistemiyle öğrenilir.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bölüm başlığı (ikon + yazı)
  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
