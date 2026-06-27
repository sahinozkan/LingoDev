import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/package_model.dart';
import '../../core/models/word_model.dart';
import '../molecules/word_card.dart';

/// Displays every word inside a package's `words` subcollection.
///
/// Firestore path: `packages/{packageId}/words`
class PackageDetailView extends StatelessWidget {
  const PackageDetailView({super.key, required this.package});

  final PackageModel package;

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
          package.title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<WordModel>>(
        stream: FirebaseFirestore.instance
            .collection('packages')
            .doc(package.id)
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
    );
  }
}
