import 'package:flutter/material.dart';

class AppConstants {
  static int beatsPerBar = 4;
  static int ticksPerBeat = 4;

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

  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color accentColor = Colors.amber;
  static const Color primaryColor = Colors.deepPurple;

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

  static double get secondsPerBeat => 60.0 / bpm;
  static double get secondsPerBar => secondsPerBeat * beatsPerBar;
  static double get secondsPerTick => secondsPerBeat / ticksPerBeat;
  static int get millisecondsPerTick => (secondsPerTick * 1000).round();

  static String get timeSignatureLabel => '$beatsPerBar/4';


}