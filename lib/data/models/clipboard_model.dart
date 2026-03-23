import 'package:flutter/material.dart';
import 'track_model.dart';

class PatternClipboard {
  // Храним ноты паттерна с относительными смещениями
  final List<MidiNote> notes;
  // Длительность паттерна в тиках
  final int duration;
  // Название инструмента
  final String instrument;
  // Цвет паттерна
  final Color color;

  PatternClipboard({
    required this.notes,
    required this.duration,
    required this.instrument,
    required this.color,
  });

  // Создаем копию с новым смещением для вставки в определенный такт
  List<MidiNote> placeAtBar(int barIndex) {
    final startTick = barIndex * 64; // 4 такта * 16 тиков = 64 тика на такт
    
    return notes.map((note) {
      return MidiNote(
        pitch: note.pitch,
        startTick: note.startTick + startTick,
        durationTicks: note.durationTicks,
      );
    }).toList();
  }

  bool get isEmpty => notes.isEmpty;
}