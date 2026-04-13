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

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'startTick': startTick,
      'durationTicks': durationTicks,
    };
  }

  factory MidiNote.fromJson(Map<String, dynamic> json) {
    return MidiNote(
      pitch: json['pitch'] as int,
      startTick: json['startTick'] as int,
      durationTicks: json['durationTicks'] as int,
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
    super.instrument = 'Пианино',
    super.volume = 1.0,
  }) : super(notes: notes ?? []);

  @override
  List<MidiNote> get notes => super.notes.cast<MidiNote>();

  Track copyWith({
    String? id,
    String? name,
    bool? isMuted,
    Color? color,
    List<MidiNote>? notes,
    String? instrument,
    double? volume,
  }) {
    return Track(
      id: id ?? this.id,
      name: name ?? this.name,
      isMuted: isMuted ?? this.isMuted,
      color: color ?? this.color,
      notes: notes ?? List<MidiNote>.from(this.notes),
      instrument: instrument ?? this.instrument,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isMuted': isMuted,
      'color': color.value,
      'instrument': instrument,
      'volume': volume,
      'notes': notes.map((n) => n.toJson()).toList(),
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      name: json['name'] as String,
      isMuted: json['isMuted'] as bool? ?? false,
      color: Color(json['color'] as int? ?? Colors.blue.value),
      instrument: json['instrument'] as String? ?? 'Пианино',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      notes: (json['notes'] as List<dynamic>? ?? [])
          .map((e) => MidiNote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}