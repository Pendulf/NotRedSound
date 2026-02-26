import 'package:flutter/material.dart';

class MidiNoteEntity {
  final int pitch;
  final int startTick;
  final int durationTicks;

  MidiNoteEntity({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
  });
}

class TrackEntity {
  final String id;
  final String name;
  final bool isMuted;
  final Color color;
  final List<MidiNoteEntity> notes;
  String instrument; // ДОБАВЛЯЕМ ПОЛЕ

  TrackEntity({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.color = Colors.blue,
    List<MidiNoteEntity>? notes,
    this.instrument = 'Piano', // ЗНАЧЕНИЕ ПО УМОЛЧАНИЮ
  }) : notes = notes ?? [];
}
