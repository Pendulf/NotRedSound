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

  int get endTick => startTick + durationTicks;

  bool containsTick(int tick) {
    return tick >= startTick && tick < endTick;
  }

  bool intersectsRange(int rangeStart, int rangeEnd) {
    return startTick < rangeEnd && endTick > rangeStart;
  }
}

class TrackEntity {
  final String id;
  final String name;
  final bool isMuted;
  final Color color;
  final List<MidiNoteEntity> notes;
  final String instrument;
  final double volume;

  TrackEntity({
    required this.id,
    required this.name,
    this.isMuted = false,
    this.color = Colors.blue,
    List<MidiNoteEntity>? notes,
    this.instrument = 'Пианино',
    this.volume = 1.0,
  }) : notes = notes ?? [];
}