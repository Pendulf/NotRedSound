import '../entities/track_entity.dart';
import '../repositories/track_repository_interface.dart';

class UpdateTrackUseCase {
  final TrackRepositoryInterface repository;

  UpdateTrackUseCase(this.repository);

  void execute(TrackEntity track) {
    repository.updateTrack(track);
  }
}
