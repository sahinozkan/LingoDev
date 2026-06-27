import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/package_model.dart';
import '../../core/services/package_repository.dart';
import 'package_detail_view.dart';

/// Displays the curated word-package catalogue fetched from Firestore.
///
/// Firestore path: `packages/{packageId}`
class PackageListView extends StatelessWidget {
  const PackageListView({super.key});

  static final _repo = PackageRepository();

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
          'Hazır Paketler',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<PackageModel>>(
        stream: _repo.watchPackages(),
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
          final packages = snapshot.data ?? [];

          if (packages.isEmpty) {
            return Center(
              child: Text(
                'Henüz paket yok',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageCard(package: packages[index]),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Inline PackageCard ─────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.package});

  final PackageModel package;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
              // ── Title ────────────────────────────────────────
              Text(
                package.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // ── Description ──────────────────────────────────
              Text(
                package.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 12),

              // ── Chips: category & level ───────────────────────
              Row(
                children: [
                  _Chip(label: package.category),
                  const SizedBox(width: 8),
                  _Chip(label: package.level),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip helper ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  static const _lila = Color(0xFFA06CD5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _lila.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lila, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: _lila,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
