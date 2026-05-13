import '../../entities/pattern_segment.dart';
import '../../entities/track_model.dart';

class HomePatternUseCases {
  const HomePatternUseCases._();

  static List<MidiNote> replaceNotesInRange({
    required List<MidiNote> sourceNotes,
    required int rangeStart,
    required int rangeEnd,
    required List<MidiNote> insertingNotes,
  }) {
    final result = <MidiNote>[];

    for (final note in sourceNotes) {
      if (!note.intersectsRange(rangeStart, rangeEnd)) {
        result.add(note);
        continue;
      }

      if (note.startTick < rangeStart) {
        final leftDuration = rangeStart - note.startTick;
        if (leftDuration > 0) {
          result.add(note.copyWith(durationTicks: leftDuration));
        }
      }

      if (note.endTick > rangeEnd) {
        final rightDuration = note.endTick - rangeEnd;
        if (rightDuration > 0) {
          result.add(
            note.copyWith(
              startTick: rangeEnd,
              durationTicks: rightDuration,
            ),
          );
        }
      }
    }

    result.addAll(insertingNotes);
    sortNotes(result);
    return result;
  }

  static PatternSegment? createSegmentFromBars({
    required Track track,
    required int startBar,
    required int barCount,
    required int ticksPerBar,
    required int savedSegmentCount,
  }) {
    final startTick = startBar * ticksPerBar;
    final endTick = (startBar + barCount) * ticksPerBar;
    final notesInRange = <MidiNote>[];

    for (final note in track.notes) {
      if (!note.intersectsRange(startTick, endTick)) continue;

      final clippedStart =
          note.startTick < startTick ? startTick : note.startTick;
      final clippedEnd = note.endTick > endTick ? endTick : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      notesInRange.add(
        MidiNote(
          pitch: note.pitch,
          startTick: clippedStart - startTick,
          durationTicks: clippedDuration,
        ),
      );
    }

    if (notesInRange.isEmpty) return null;

    sortNotes(notesInRange);

    return PatternSegment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Сегмент ${savedSegmentCount + 1}',
      notes: notesInRange,
      barLength: barCount,
      createdAt: DateTime.now(),
    );
  }

  static List<MidiNote> copySegmentToBar({
    required List<MidiNote> sourceNotes,
    required PatternSegment segment,
    required int targetBarIndex,
    required int ticksPerBar,
  }) {
    final targetStart = targetBarIndex * ticksPerBar;
    final targetEnd = targetStart + (segment.barLength * ticksPerBar);

    return replaceNotesInRange(
      sourceNotes: sourceNotes,
      rangeStart: targetStart,
      rangeEnd: targetEnd,
      insertingNotes: segment.copyNotesToBar(targetBarIndex, ticksPerBar),
    );
  }

  static List<MidiNote> copyNotesFromRange({
    required List<MidiNote> sourceNotes,
    required int sourceStart,
    required int sourceEnd,
    required int targetStart,
  }) {
    final result = <MidiNote>[];

    for (final note in sourceNotes) {
      if (!note.intersectsRange(sourceStart, sourceEnd)) continue;

      final clippedStart =
          note.startTick < sourceStart ? sourceStart : note.startTick;
      final clippedEnd = note.endTick > sourceEnd ? sourceEnd : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      result.add(
        MidiNote(
          pitch: note.pitch,
          startTick: targetStart + (clippedStart - sourceStart),
          durationTicks: clippedDuration,
        ),
      );
    }

    sortNotes(result);
    return result;
  }

  static List<MidiNote> notesInBar({
    required Track track,
    required int barIndex,
    required int ticksPerBar,
  }) {
    final startTick = barIndex * ticksPerBar;
    final endTick = startTick + ticksPerBar;
    final result = <MidiNote>[];

    for (final note in track.notes) {
      if (!note.intersectsRange(startTick, endTick)) continue;

      final clippedStart =
          note.startTick < startTick ? startTick : note.startTick;
      final clippedEnd = note.endTick > endTick ? endTick : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      result.add(
        MidiNote(
          pitch: note.pitch,
          startTick: clippedStart - startTick,
          durationTicks: clippedDuration,
        ),
      );
    }

    sortNotes(result);
    return result;
  }

  static void sortNotes(List<MidiNote> notes) {
    notes.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });
  }
}
