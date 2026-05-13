import '../../../core/constants/app_constants.dart';
import '../../../core/styles/project_style.dart';
import '../../../core/styles/project_styles.dart';
import '../../entities/track_model.dart';
import '../../entities/project_snapshot.dart';

class HomeProjectUseCases {
  const HomeProjectUseCases._();

  static ProjectSnapshot buildSnapshot({
    required ProjectStyleType styleType,
    required List<Track> tracks,
  }) {
    final style = ProjectStyles.byType(styleType);

    return ProjectSnapshot(
      bpm: AppConstants.bpm,
      totalBars: AppConstants.totalBars,
      beatsPerBar: AppConstants.beatsPerBar,
      ticksPerBeat: AppConstants.ticksPerBeat,
      styleId: style.id,
      tracks: tracks,
    );
  }

  static ProjectStyleType applySnapshotMetrics(ProjectSnapshot snapshot) {
    final loadedStyle = ProjectStyles.byId(snapshot.styleId);

    AppConstants.applyProjectStyle(loadedStyle.type);
    AppConstants.updateBpm(snapshot.bpm);
    AppConstants.updateTotalBars(snapshot.totalBars);
    AppConstants.updateTimeSignature(
      newBeatsPerBar: snapshot.beatsPerBar,
      newTicksPerBeat: snapshot.ticksPerBeat,
    );

    return loadedStyle.type;
  }
}
