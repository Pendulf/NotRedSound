// lib/data/models/pattern_segment.dart
import 'package:flutter/material.dart';
import 'track_model.dart';

class PatternSegment {
  final String id;
  final String name;
  final List<MidiNote> notes;
  final int barLength;
  final DateTime createdAt;

  PatternSegment({
    required this.id,
    required this.name,
    required this.notes,
    required this.barLength,
    required this.createdAt,
  });

  // Копирование нот со смещением по тактам
  List<MidiNote> copyNotesToBar(int targetBarIndex, int ticksPerBar) {
    final startTick = targetBarIndex * ticksPerBar;
    return notes.map((note) {
      return MidiNote(
        pitch: note.pitch,
        startTick: startTick + (note.startTick % ticksPerBar),
        durationTicks: note.durationTicks,
      );
    }).toList();
  }

  PatternSegment copyWith({
    String? id,
    String? name,
    List<MidiNote>? notes,
    int? barLength,
    DateTime? createdAt,
  }) {
    return PatternSegment(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      barLength: barLength ?? this.barLength,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}