import 'package:flutter/material.dart';
import '../../domain/entities/track_entity.dart';

class MidiNote extends MidiNoteEntity {
  MidiNote({
    required super.pitch,
    required super.startTick,
    required super.durationTicks,
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

class Track extends TrackEntity {
  Track({
    required super.id,
    required super.name,
    super.isMuted = false,
    super.color = Colors.blue,
    List<MidiNote>? notes,
    super.instrument = 'Piano', // ДОБАВЛЯЕМ ПОЛЕ
  }) : super(notes: notes ?? []);

  @override
  List<MidiNote> get notes => super.notes as List<MidiNote>;

  void toggleMute() {
    // Будет реализовано через контроллер
  }
}
