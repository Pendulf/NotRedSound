import '../../domain/entities/track_entity.dart';
import '../../domain/repositories/track_repository_interface.dart';
import '../models/track_model.dart';

class TrackRepository implements TrackRepositoryInterface {
  final List<Track> _tracks = [];

  @override
  List<TrackEntity> getTracks() => _tracks;

  @override
  void addTrack(TrackEntity track) {
    _tracks.add(track as Track);
  }

  @override
  void updateTrack(TrackEntity track) {
    final index = _tracks.indexWhere((t) => t.id == track.id);
    if (index != -1) {
      _tracks[index] = track as Track;
    }
  }

  @override
/*************  ✨ Windsurf Command ⭐  *************/
  /// Removes a track with the given id from the repository.
  ///
  /// If a track with the given id exists, it is removed from the repository.
  /// Otherwise, this method does nothing.
/*******  5b12ff97-f02f-41bf-b1bc-33e3a7fef33c  *******/  void deleteTrack(String id) {
    _tracks.removeWhere((track) => track.id == id);
  }

  @override
  void toggleMute(String id) {
    final index = _tracks.indexWhere((track) => track.id == id);
    if (index != -1) {
      final track = _tracks[index];
      _tracks[index] = track.copyWith(isMuted: !track.isMuted);
    }
  }
}