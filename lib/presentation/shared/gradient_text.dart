import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final List<Color> gradientColors;
  final TextAlign textAlign;

  const GradientText({
    super.key,
    required this.text,
    this.fontSize = 28,
    this.fontWeight = FontWeight.bold,
    this.gradientColors = const [Colors.red, Colors.purple, Colors.blue],
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
        textAlign: textAlign,
      ),
    );
  }
}