import '../../../core/constants/app_constants.dart';
import '../../../core/music/scale_autotune.dart';
import '../../../core/services/voice_recorder_service.dart';
import '../../../data/models/track_model.dart';

class PianoRollVoiceUseCases {
  const PianoRollVoiceUseCases._();

  static List<MidiNote> convertVoiceNotes({
    required List<VoiceNote> voiceNotes,
    required int insertStartTick,
    required int maxTicks,
    int octaveShift = 0,
  }) {
    final result = <MidiNote>[];

    for (final voiceNote in voiceNotes) {
      final pitch = ScaleAutotune.quantizePitch(
        pitch: voiceNote.pitch + octaveShift,
        minNote: AppConstants.minNote,
        maxNote: AppConstants.maxNote,
      );
      final startTick = insertStartTick + voiceNote.startTick;
      final durationTicks = voiceNote.durationTicks.clamp(1, maxTicks).toInt();

      if (startTick < 0 || startTick >= maxTicks) continue;
      if (startTick + durationTicks > maxTicks) continue;

      result.add(
        MidiNote(
          pitch: pitch,
          startTick: startTick,
          durationTicks: durationTicks,
        ),
      );
    }

    return result;
  }

  static List<MidiNote> transposeBatch({
    required List<MidiNote> batch,
    required int semitones,
    required int minNote,
    required int maxNote,
  }) {
    return batch
        .map(
          (note) => note.copyWith(
            pitch: (note.pitch + semitones).clamp(minNote, maxNote).toInt(),
          ),
        )
        .toList();
  }
}
