import 'package:flutter/material.dart';
import '../../../data/models/track_model.dart';

class PatternPainter extends CustomPainter {
  final List<MidiNote> notes;
  final Color color;
  final double barWidth;
  final double previewHeight;
  final int minNote;
  final int maxNote;
  final int ticksPerBar;

  PatternPainter({
    required this.notes,
    required this.color,
    required this.barWidth,
    required this.previewHeight,
    required this.minNote,
    required this.maxNote,
    required this.ticksPerBar,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    for (final note in notes) {
      final normalizedY = _normalizeNotePosition(note.pitch);
      final relativePosition = note.startTick / ticksPerBar;
      final noteX = relativePosition * barWidth;

      final noteWidth =
          ((note.durationTicks / ticksPerBar) * barWidth).clamp(2.0, barWidth);

      final noteHeight =
          (previewHeight / (maxNote - minNote + 1) * 0.8).clamp(2.0, 10.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            noteX,
            normalizedY - noteHeight / 2,
            noteWidth,
            noteHeight,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  double _normalizeNotePosition(int pitch) {
    final range = maxNote - minNote;
    if (range <= 0) return previewHeight / 2;

    final position = (maxNote - pitch) / range;
    return position * previewHeight;
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.color != color ||
        oldDelegate.minNote != minNote ||
        oldDelegate.maxNote != maxNote ||
        oldDelegate.ticksPerBar != ticksPerBar ||
        oldDelegate.barWidth != barWidth;
  }
}