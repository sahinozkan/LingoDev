import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/word_model.dart';

/// A card widget that displays a single [WordModel].
///
/// Shows the English word, Turkish translation, mastery level indicators,
/// and up to 3 synonym chips.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    this.onTap,
  });

  final WordModel word;
  final VoidCallback? onTap;

  // ── Design tokens ──────────────────────────────────────────
  static const _cardColor = Color(0xFF1E1E1E);
  static const _primaryColor = Color(0xFFA06CD5);
  static const _emptyDotColor = Color(0xFF444444);
  static const _maxSynonyms = 3;
  static const _masteryDots = 5;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: _primaryColor.withOpacity(0.12),
        highlightColor: _primaryColor.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EnglishLabel(text: word.english),
              const SizedBox(height: 4),
              _TurkishLabel(text: word.turkish),
              const SizedBox(height: 12),
              _MasteryRow(masteryLevel: word.masteryLevel),
              if (word.synonyms.isNotEmpty) ...[
                const SizedBox(height: 10),
                _SynonymChips(synonyms: word.synonyms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _EnglishLabel extends StatelessWidget {
  const _EnglishLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _TurkishLabel extends StatelessWidget {
  const _TurkishLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: WordCard._primaryColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.masteryLevel});
  final int masteryLevel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(WordCard._masteryDots, (i) {
        final filled = i < masteryLevel;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? WordCard._primaryColor : WordCard._emptyDotColor,
            ),
          ),
        );
      }),
    );
  }
}

class _SynonymChips extends StatelessWidget {
  const _SynonymChips({required this.synonyms});
  final List<String> synonyms;

  @override
  Widget build(BuildContext context) {
    final visible = synonyms.take(WordCard._maxSynonyms).toList();
    final overflow = synonyms.length - WordCard._maxSynonyms;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...visible.map((s) => _Chip(label: s)),
        if (overflow > 0) _Chip(label: '+$overflow', muted: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.muted = false});
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted
            ? WordCard._emptyDotColor
            : WordCard._primaryColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: muted
              ? WordCard._emptyDotColor
              : WordCard._primaryColor.withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: muted ? Colors.white54 : WordCard._primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
