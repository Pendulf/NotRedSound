import '../entities/note_range.dart';
import '../entities/track_entity.dart';

class BarNoteService {
  const BarNoteService._();

  static List<MidiNoteEntity> notesInBar({
    required TrackEntity track,
    required int barIndex,
    required int ticksPerBar,
  }) {
    final startTick = barIndex * ticksPerBar;
    final endTick = startTick + ticksPerBar;
    final result = <MidiNoteEntity>[];

    for (final note in track.notes) {
      if (!note.intersectsRange(startTick, endTick)) continue;

      final clippedStart =
          note.startTick < startTick ? startTick : note.startTick;
      final clippedEnd = note.endTick > endTick ? endTick : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      result.add(
        MidiNoteEntity(
          pitch: note.pitch,
          startTick: clippedStart - startTick,
          durationTicks: clippedDuration,
        ),
      );
    }

    result.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });

    return result;
  }

  static NoteRange noteRange(
    TrackEntity track, {
    int emptyMin = 48,
    int emptyMax = 84,
    int padding = 2,
  }) {
    if (track.notes.isEmpty) {
      return NoteRange(min: emptyMin, max: emptyMax);
    }

    int minPitch = track.notes.first.pitch;
    int maxPitch = track.notes.first.pitch;

    for (final note in track.notes) {
      if (note.pitch < minPitch) minPitch = note.pitch;
      if (note.pitch > maxPitch) maxPitch = note.pitch;
    }

    return NoteRange(
      min: (minPitch - padding).clamp(0, 127).toInt(),
      max: (maxPitch + padding).clamp(0, 127).toInt(),
    );
  }
}
