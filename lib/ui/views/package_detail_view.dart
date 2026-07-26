import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/package_model.dart';
import '../../core/models/word_model.dart';
import '../../core/services/word_repository.dart';
import '../../core/theme/app_colors.dart';
import '../atoms/app_button.dart';
import '../molecules/word_card.dart';

/// Displays every word inside a package's `words` subcollection.
///
/// Firestore path: `packages/{packageId}/words`
class PackageDetailView extends StatefulWidget {
  const PackageDetailView({super.key, required this.package});

  final PackageModel package;

  @override
  State<PackageDetailView> createState() => _PackageDetailViewState();
}

class _PackageDetailViewState extends State<PackageDetailView> {
  /// StreamBuilder'dan gelen en güncel kelime listesi — "Listeme Ekle"
  /// butonuna basıldığında bu liste içe aktarılır.
  List<WordModel> _packageWords = [];

  bool _isImporting = false;

  Future<void> _handleImport() async {
    if (_isImporting || _packageWords.isEmpty) return;
    setState(() => _isImporting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final added =
          await WordRepository(userId: uid).importWords(_packageWords);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? '$added kelime listene eklendi'
                : 'Bu paketteki tüm kelimeler zaten listende',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ekleme başarısız, tekrar dene',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.package.title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<WordModel>>(
              stream: FirebaseFirestore.instance
                  .collection('packages')
                  .doc(widget.package.id)
                  .collection('words')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  .map((snap) => snap.docs.map(WordModel.fromFirestore).toList()),
              builder: (context, snapshot) {
                // ── 1. Loading ──────────────────────────────────────
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFA06CD5)),
                  );
                }

                // ── 2. Error ────────────────────────────────────────
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Bir hata oluştu',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                // ── 3. Data ─────────────────────────────────────────
                final words = snapshot.data ?? [];
                _packageWords = words;

                if (words.isEmpty) {
                  return Center(
                    child: Text(
                      'Bu pakette henüz kelime yok',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WordCard(word: words[index]),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AppButton(
                text: 'Kelime Listeme Ekle',
                icon: Icons.playlist_add_rounded,
                isLoading: _isImporting,
                onPressed: _isImporting ? null : _handleImport,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
