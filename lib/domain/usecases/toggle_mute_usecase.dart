import '../repositories/track_repository_interface.dart';

class ToggleMuteUseCase {
  final TrackRepositoryInterface repository;

  ToggleMuteUseCase(this.repository);

  void execute(String id) {
    repository.toggleMute(id);
  }
}
