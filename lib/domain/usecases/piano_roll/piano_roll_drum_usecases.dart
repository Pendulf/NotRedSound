import '../../entities/voice_note_entity.dart';
import '../../entities/track_model.dart';

class PianoRollDrumUseCases {
  const PianoRollDrumUseCases._();

  static bool isDrumTrack(Track track) {
    return track.instrument == 'Ударные' ||
        track.name.toLowerCase().contains('барабан');
  }

  static List<MidiNote> convertDrumVoiceNotes({
    required List<VoiceNoteEntity> voiceNotes,
    required int insertStartTick,
    required int maxTicks,
    required List<int> allowedNotes,
  }) {
    final allowed = allowedNotes.toSet();
    final result = <MidiNote>[];
    final occupied = <String>{};

    for (final voiceNote in voiceNotes) {
      if (!allowed.contains(voiceNote.pitch)) continue;

      final startTick = insertStartTick + voiceNote.startTick;
      if (startTick < 0 || startTick >= maxTicks) continue;

      final key = '${voiceNote.pitch}:$startTick';
      if (!occupied.add(key)) continue;

      result.add(
        MidiNote(
          pitch: voiceNote.pitch,
          startTick: startTick,
          durationTicks: 1,
        ),
      );
    }

    return result;
  }
}
