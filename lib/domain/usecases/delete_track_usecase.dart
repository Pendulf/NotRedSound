import '../repositories/track_repository_interface.dart';

class DeleteTrackUseCase {
  final TrackRepositoryInterface repository;

  DeleteTrackUseCase(this.repository);

  void execute(String id) {
    repository.deleteTrack(id);
  }
}
