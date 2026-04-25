import 'package:flutter/material.dart';

import '../project_style.dart';
import '../project_styles.dart';

class AppConstants {
  static int beatsPerBar = 4;
  static int ticksPerBeat = 4;

  static ProjectStyleType currentStyleType = ProjectStyleType.standard;

  static bool get isRhythm3 => ticksPerBeat == 3;
  static bool get isRhythm4 => ticksPerBeat == 4;

  static int bpm = 60;
  static int totalBars = 20;

  static int get ticksPerBar => beatsPerBar * ticksPerBeat;
  static int get maxTicks => totalBars * ticksPerBar;
  static int get maxBars => totalBars;

  static double barWidth = 160;
  static const double previewHeight = 40;
  static const double horizontalPadding = 16;

  static const int minNote = 36;
  static const int maxNote = 84;

  static const double noteCellWidth = 35;
  static const double keyAreaWidth = 90;

  static const int defaultNoteDurationTicks = 1;
  static const int minNoteDurationTicks = 1;

  static double get secondsPerBeat => 60.0 / bpm;
  static double get secondsPerBar => secondsPerBeat * beatsPerBar;
  static double get secondsPerTick => secondsPerBeat / ticksPerBeat;
  static int get millisecondsPerTick => (secondsPerTick * 1000).round();

  static String get timeSignatureLabel => '$beatsPerBar/4';

  static ProjectStyle get currentStyle => ProjectStyles.byType(currentStyleType);
  static String get background => currentStyle.backgroundAsset;
  static Color get styleColor => currentStyle.primaryColor;
  static Color get styleAccentColor => currentStyle.secondaryColor;
  static String get styleLabel => currentStyle.displayName;

  static const List<Color> brandGradient = [
    Colors.red,
    Colors.purple,
    Colors.blue,
  ];

  static void applyProjectStyle(ProjectStyleType styleType) {
  currentStyleType = styleType;

  switch (styleType) {
    case ProjectStyleType.classic:
      beatsPerBar = 3;
      ticksPerBeat = 3;
      break;

    case ProjectStyleType.standard:
    case ProjectStyleType.rock:
    case ProjectStyleType.electro:
      beatsPerBar = 4;
      ticksPerBeat = 4;
      break;
  }
}

  static void updateBpm(int newBpm) {
    bpm = newBpm.clamp(40, 240);
  }

  static void updateTotalBars(int newTotalBars) {
    totalBars = newTotalBars.clamp(1, 100);
  }

  static void updateTimeSignature({
    required int newBeatsPerBar,
    int? newTicksPerBeat,
  }) {
    beatsPerBar = newBeatsPerBar.clamp(1, 12);
    if (newTicksPerBeat != null) {
      ticksPerBeat = newTicksPerBeat.clamp(1, 16);
    }
  }

  static void resetProjectMetrics() {
    bpm = 60;
    totalBars = 20;
    beatsPerBar = 4;
    ticksPerBeat = 4;
  }

  static void setRhythm3() {
    ticksPerBeat = 3;
  }

  static void setRhythm4() {
    ticksPerBeat = 4;
  }
}
