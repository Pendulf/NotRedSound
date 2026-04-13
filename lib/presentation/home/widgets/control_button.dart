import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const ControlButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: IconButton(
          icon: Icon(icon, color: color, size: 18),
          onPressed: onPressed,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          splashRadius: 16,
        ),
      ),
    );
  }
}