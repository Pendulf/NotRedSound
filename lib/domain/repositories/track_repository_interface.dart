import '../entities/track_entity.dart';

abstract class TrackRepositoryInterface {
  List<TrackEntity> getTracks();
  void addTrack(TrackEntity track);
  void updateTrack(TrackEntity track);
  void deleteTrack(String id);
  void toggleMute(String id);
}
