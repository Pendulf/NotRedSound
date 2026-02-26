import 'package:flutter/material.dart';

class PianoKeyWidget extends StatelessWidget {
  final bool isBlackKey;
  final String? octaveName;
  final Color trackColor;
  final double keyAreaWidth;

  const PianoKeyWidget({
    super.key,
    required this.isBlackKey,
    this.octaveName,
    required this.trackColor,
    required this.keyAreaWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: keyAreaWidth,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800),
          right: BorderSide(color: Colors.grey.shade700),
        ),
        color: isBlackKey ? Colors.grey[900] : Colors.grey[850],
      ),
      child: Stack(
        children: [
          if (isBlackKey)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: keyAreaWidth / 3,
              child: Container(color: Colors.grey[850]),
            ),
          Center(
            child: octaveName != null && octaveName!.isNotEmpty
                ? Text(
                    octaveName!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: trackColor,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}