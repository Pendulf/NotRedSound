import '../entities/track_entity.dart';
import '../repositories/track_repository_interface.dart';

class AddTrackUseCase {
  final TrackRepositoryInterface repository;

  AddTrackUseCase(this.repository);

  void execute(TrackEntity track) {
    repository.addTrack(track);
  }
}
