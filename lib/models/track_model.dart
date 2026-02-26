import 'package:flutter/material.dart';

class MidiNote {
  int pitch;
  int startTick;
  int durationTicks;

  MidiNote({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
  });

  MidiNote copyWith({
    int? pitch,
    int? startTick,
    int? durationTicks,
  }) {
    return MidiNote(
      pitch: pitch ?? this.pitch,
      startTick: startTick ?? this.startTick,
      durationTicks: durationTicks ?? this.durationTicks,
    );
  }
}

class Track {
  String id;
  String name;
  bool isMuted;
  Color color;
  List<MidiNote> notes;
  String instrument; // НОВОЕ ПОЛЕ: инструмент дорожки

  Track({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.color = Colors.blue,
    List<MidiNote>? notes,
    this.instrument = 'Piano', // По умолчанию пианино
  }) : notes = notes ?? [];
}