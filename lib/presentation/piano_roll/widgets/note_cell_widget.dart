import 'package:flutter/material.dart';

class NoteCellWidget extends StatelessWidget {
  final bool isNotePresent;
  final bool isFirstColumn;
  final Color noteColor;
  final Color lineColor;
  final double lineWidth;
  final VoidCallback onTap;

  const NoteCellWidget({
    super.key,
    required this.isNotePresent,
    required this.isFirstColumn,
    required this.noteColor,
    required this.lineColor,
    required this.lineWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            left: isFirstColumn ? BorderSide(color: lineColor) : BorderSide.none,
            right: BorderSide(color: lineColor, width: lineWidth),
            bottom: BorderSide(color: Colors.grey.shade800),
          ),
          color: isNotePresent ? noteColor.withValues(alpha: 0.7) : Colors.transparent,
        ),
      ),
    );
  }
}