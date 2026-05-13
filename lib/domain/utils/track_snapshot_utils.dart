import '../entities/track_model.dart';

class TrackSnapshotUtils {
  const TrackSnapshotUtils._();

  static MidiNote cloneNote(MidiNote note) {
    return MidiNote(
      pitch: note.pitch,
      startTick: note.startTick,
      durationTicks: note.durationTicks,
    );
  }

  static List<MidiNote> cloneNotes(List<MidiNote> notes) {
    return notes.map(cloneNote).toList();
  }

  static Track cloneTrack(Track track) {
    return track.copyWith(notes: cloneNotes(track.notes));
  }

  static List<Track> cloneTracks(List<Track> tracks) {
    return tracks.map(cloneTrack).toList();
  }
}
