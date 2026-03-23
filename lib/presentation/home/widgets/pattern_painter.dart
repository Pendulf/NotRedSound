import 'package:flutter/material.dart';
import '../../../data/models/track_model.dart';

class PatternPainter extends CustomPainter {
  final List<MidiNote> notes;
  final Color color;
  final double barWidth;
  final double previewHeight;
  final int minNote;
  final int maxNote;
  final int ticksPerBar; // Добавляем параметр для тиков в такте

  PatternPainter({
    required this.notes,
    required this.color,
    required this.barWidth,
    required this.previewHeight,
    required this.minNote,
    required this.maxNote,
    required this.ticksPerBar, // Новый параметр
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (final note in notes) {
      final double normalizedY = _normalizeNotePosition(note.pitch);
      
      // Вычисляем относительную позицию в пределах такта (0-1)
      final double relativePosition = (note.startTick % ticksPerBar) / ticksPerBar;
      final double noteX = relativePosition * barWidth;
      
      // Длительность ноты: делим на 4 (используем ticksPerBar * 4 для 4-кратного уменьшения)
      final double noteWidth = (note.durationTicks / ticksPerBar.toDouble()) * barWidth ;
      final double noteHeight = previewHeight / (maxNote - minNote + 1) * 0.8;



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
    final int range = maxNote - minNote;
    if (range == 0) return previewHeight / 2;
    final double position = (maxNote - pitch) / range;
    return position * previewHeight;
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return oldDelegate.notes != notes ||
        oldDelegate.color != color ||
        oldDelegate.minNote != minNote ||
        oldDelegate.maxNote != maxNote;
  }
}