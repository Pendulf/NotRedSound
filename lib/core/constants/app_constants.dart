import 'package:flutter/material.dart';

class AppConstants {
  static const int beatsPerBar = 4; // 4/4 размер
  static const int ticksPerBeat = 16; // 1/16 ноты

  // Параметры по умолчанию
  static int bpm = 60; 
  static int totalBars = 20;

  // Вычисляемые параметры
  static int get maxTicks => totalBars * ticksPerBeat * beatsPerBar;
  static int get maxBars => totalBars;

  // Визуальные параметры
  static double barWidth = 160;
  static const double previewHeight = 40;
  static const double horizontalPadding = 16;

  // MIDI параметры
  static const int minNote = 48;
  static const int maxNote = 84;
  static const double noteCellWidth = 35;
  static const double keyAreaWidth = 90;

  // Цвета
  static const Color backgroundColor = Color(0xFF121212);
  static const Color surfaceColor = Color(0xFF1E1E1E);
  static const Color accentColor = Colors.amber;
  static const Color primaryColor = Colors.deepPurple;

  // Методы для обновления
  static void updateBpm(int newBpm) {
    bpm = newBpm.clamp(40, 240);
  }

  static void updateTotalBars(int newTotalBars) {
    totalBars = newTotalBars.clamp(1, 100);
  }

  // Длительность одного такта в секундах
  static double get secondsPerBar => 60.0 / bpm * beatsPerBar;

  // Длительность одного тика в секундах
  static double get secondsPerTick =>
      secondsPerBar / (ticksPerBeat * beatsPerBar);

  // Длительность одного тика в миллисекундах (для таймера)
  static int get millisecondsPerTick => (secondsPerTick * 1000).round();
}
