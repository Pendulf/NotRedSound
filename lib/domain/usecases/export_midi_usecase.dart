import '../entities/track_entity.dart';

abstract class ExportMidiUseCase {
  Future<void> execute(
    List<TrackEntity> tracks, {
    required bool share,
    String? fileName,
    int bpm = 120,
  });
}
