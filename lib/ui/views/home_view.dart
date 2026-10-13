import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/package_model.dart';
import '../../core/models/word_model.dart';
import '../../core/services/package_repository.dart';
import '../../core/services/seeder_service.dart'; // TODO: Yükleme sonrası silinecek
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../molecules/word_card.dart';
import 'add_word_view.dart';
import 'login_view.dart';
import 'package_list_view.dart';
import 'practice_view.dart';

/// LingoDev Ana Sayfa
/// Giriş yapan kullanıcının kelimelerini Firestore'dan gerçek zamanlı listeler.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final WordRepository _wordRepo;

  // TODO: Yükleme sonrası silinecek
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _wordRepo = WordRepository(userId: uid);
  }

  // TODO: Yükleme sonrası silinecek
  Future<void> _runSeeder() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);

    try {
      final count = await SeederService.seedAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count Paket Başarıyla Yüklendi ✅'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  /// [PackageRepository.watchPackages()] için güvenli stream sarmalayıcı.
  /// Herhangi bir exception'ı yakalar ve StreamBuilder'ın hasError
  /// branch'ine yönlendirir (uygulama çökmez).
  Stream<List<PackageModel>> _packagesStream() {
    try {
      return PackageRepository().watchPackages();
    } catch (e) {
      // ignore: avoid_print
      print('HomeView packages stream init error: $e');
      return Stream.error(e);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddWordView()),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // ── AppBar ───────────────────────────────────────
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Logo
                    Image.asset(
                      'assets/images/logo_monogram.png',
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    // Hoş geldin metni
                    Expanded(
                      child: Text(
                        user?.email ?? 'Hoş Geldin!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // TODO: Yükleme sonrası silinecek — Seeder tetikleyici buton
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _runSeeder,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF1A1A2E),
                              border: Border.all(
                                color: const Color(0xFFA06CD5).withOpacity(0.5),
                                width: 0.8,
                              ),
                            ),
                            child: _isSeeding
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFA06CD5),
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Color(0xFFA06CD5),
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    // Çıkış butonu
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _handleLogout(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surfaceLight,
                            border: Border.all(
                              color: AppColors.textHint.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Ayırıcı ─────────────────────────────────────
            Container(
              height: 1,
              color: AppColors.textHint.withOpacity(0.15),
            ),

            // ── Ana İçerik (Paketler + Kelimeler) ─────────────
            Expanded(
              child: StreamBuilder<List<WordModel>>(
                stream: _wordRepo.watchWords(),
                builder: (context, wordSnapshot) {
                  // 1. Yükleniyor
                  if (wordSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFA06CD5),
                      ),
                    );
                  }

                  // 2. Hata
                  if (wordSnapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Bir hata oluştu',
                        style: TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final words = wordSnapshot.data ?? [];

                  return CustomScrollView(
                    slivers: [
                      // ── Sliver 1: Hazır Paketler header ────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Hazır Paketler',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PackageListView(),
                                  ),
                                ),
                                child: Text(
                                  'Tümünü Gör',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFFA06CD5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Sliver 2: Hazır Paketler yatay önizleme ─
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 120,
                          child: StreamBuilder<List<PackageModel>>(
                            stream: _packagesStream(),
                            builder: (context, pkgSnapshot) {
                              if (pkgSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFA06CD5),
                                  ),
                                );
                              }

                              // ── Hata branch (debug print) ──────────
                              if (pkgSnapshot.hasError) {
                                // ignore: avoid_print
                                print('HomeView packages error: ${pkgSnapshot.error}');
                                return const SizedBox.shrink(); // boş göster, hata mesajı değil
                              }

                              final packages =
                                  (pkgSnapshot.data ?? []).take(3).toList();
                              if (packages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Henüz paket yok',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white38,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: packages.length,
                                itemBuilder: (context, index) {
                                  final pkg = packages[index];
                                  return _PackagePreviewCard(
                                      package: pkg);
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      // ── Sliver 3: Kelimelerim header ────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kelimelerim',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PracticeView(),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.psychology_rounded,
                                  size: 18,
                                  color: Color(0xFFA06CD5),
                                ),
                                label: Text(
                                  'Pratik Yap',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFFA06CD5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Sliver 4: Kelime listesi ─────────────────
                      if (words.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.menu_book_outlined,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz kelime eklemedin',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: WordCard(word: words[index]),
                              ),
                              childCount: words.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Package preview card (used in HomeView horizontal list) ───────────────

class _PackagePreviewCard extends StatelessWidget {
  const _PackagePreviewCard({required this.package});

  final PackageModel package;

  static const _lila = Color(0xFFA06CD5);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PackageListView()),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title
            Text(
              package.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            // Category chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _lila.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _lila, width: 1),
              ),
              child: Text(
                package.category,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _lila,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
