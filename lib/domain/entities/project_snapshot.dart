import 'track_entity.dart';

class ProjectSnapshot {
  final int bpm;
  final int totalBars;
  final int beatsPerBar;
  final int ticksPerBeat;
  final String styleId;
  final List<TrackEntity> tracks;

  const ProjectSnapshot({
    required this.bpm,
    required this.totalBars,
    required this.beatsPerBar,
    required this.ticksPerBeat,
    required this.styleId,
    required this.tracks,
  });
}
