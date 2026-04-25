import '../../../data/models/track_model.dart';

class PianoRollPlaybackUseCases {
  const PianoRollPlaybackUseCases._();

  static bool canStartPlayback(Track track) {
    return !track.isMuted && track.notes.isNotEmpty;
  }

  static int clampStartTick({
    required int tick,
    required int maxTicks,
  }) {
    if (maxTicks <= 0) return 0;
    return tick.clamp(0, maxTicks - 1).toInt();
  }

  static int previewDurationMs({
    required int durationTicks,
    required int millisecondsPerTick,
  }) {
    return (durationTicks * millisecondsPerTick).clamp(1, 10000).toInt();
  }
}
