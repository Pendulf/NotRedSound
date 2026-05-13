import '../../../core/styles/project_style.dart';
import '../../entities/track_model.dart';

class HomeTrackUseCases {
  const HomeTrackUseCases._();

  static Track createTrack({
    required ProjectStyle style,
    required int index,
  }) {
    return Track(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: style.defaultTrackName(index),
      color: style.colorForTrack(index),
      notes: const [],
      instrument: style.defaultTrackInstrument(index),
      volume: 1.0,
    );
  }

  static List<Track> createStarterTracks(ProjectStyle style) {
    return List<Track>.generate(style.starterTracks.length, (index) {
      final starter = style.starterTracks[index];
      return Track(
        id: '${style.id}_${DateTime.now().microsecondsSinceEpoch}_$index',
        name: starter.name,
        color: style.colorForTrack(index),
        notes: const [],
        instrument: starter.instrument,
        volume: 1.0,
      );
    });
  }

  static List<Track> soloOrResetMute({
    required List<Track> tracks,
    required String targetTrackId,
  }) {
    final targetTrack =
        tracks.where((track) => track.id == targetTrackId).firstOrNull;
    if (targetTrack == null) return tracks;

    if (targetTrack.isMuted) {
      return tracks
          .map(
              (track) => track.isMuted ? track.copyWith(isMuted: false) : track)
          .toList();
    }

    return tracks
        .map((track) => track.copyWith(isMuted: track.id != targetTrackId))
        .toList();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
