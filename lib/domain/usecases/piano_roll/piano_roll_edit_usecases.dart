import '../../../data/models/track_model.dart';

class PianoRollEditUseCases {
  const PianoRollEditUseCases._();

  static void sortNotes(List<MidiNote> notes) {
    notes.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });
  }

  static MidiNote? findNoteCovering({
    required List<MidiNote> notes,
    required int pitch,
    required int tick,
  }) {
    for (final note in notes) {
      if (note.pitch == pitch && note.containsTick(tick)) return note;
    }
    return null;
  }

  static bool canPlaceNote({
    required List<MidiNote> notes,
    required int pitch,
    required int startTick,
    required int durationTicks,
    required int maxTicks,
  }) {
    final endTick = startTick + durationTicks;
    if (startTick < 0 || endTick > maxTicks) return false;

    for (final note in notes) {
      if (note.pitch != pitch) continue;
      if (note.intersectsRange(startTick, endTick)) return false;
    }

    return true;
  }

  static MidiNote createNoteFromTwoTaps({
    required int pitch,
    required int firstTick,
    required int secondTick,
  }) {
    final actualStart = firstTick <= secondTick ? firstTick : secondTick;
    final actualEnd = firstTick <= secondTick ? secondTick : firstTick;

    return MidiNote(
      pitch: pitch,
      startTick: actualStart,
      durationTicks: (actualEnd - actualStart) + 1,
    );
  }

  static List<MidiNote> splitNotesToGrid(List<MidiNote> source) {
    final result = <MidiNote>[];

    for (final note in source) {
      for (int tick = note.startTick; tick < note.endTick; tick++) {
        result.add(
          MidiNote(
            pitch: note.pitch,
            startTick: tick,
            durationTicks: 1,
          ),
        );
      }
    }

    sortNotes(result);
    return result;
  }

  static List<MidiNote> mergeAdjacentSamePitch(List<MidiNote> source) {
    if (source.isEmpty) return [];

    final sorted = source
        .map((note) => MidiNote(
              pitch: note.pitch,
              startTick: note.startTick,
              durationTicks: note.durationTicks,
            ))
        .toList()
      ..sort((a, b) {
        final byPitch = a.pitch.compareTo(b.pitch);
        if (byPitch != 0) return byPitch;

        final byStart = a.startTick.compareTo(b.startTick);
        if (byStart != 0) return byStart;

        return a.durationTicks.compareTo(b.durationTicks);
      });

    final merged = <MidiNote>[];
    MidiNote current = sorted.first;

    for (int i = 1; i < sorted.length; i++) {
      final next = sorted[i];

      final currentEnd = current.startTick + current.durationTicks;
      final nextEnd = next.startTick + next.durationTicks;

      final samePitch = current.pitch == next.pitch;
      final touchesOrOverlaps = next.startTick <= currentEnd;

      if (samePitch && touchesOrOverlaps) {
        final mergedEnd = currentEnd > nextEnd ? currentEnd : nextEnd;
        current = MidiNote(
          pitch: current.pitch,
          startTick: current.startTick,
          durationTicks: mergedEnd - current.startTick,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }

    merged.add(current);
    sortNotes(merged);
    return merged;
  }
}
