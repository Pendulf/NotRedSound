import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/styles/project_style.dart';
import '../../core/services/audio_service.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../data/usecases/export_midi_usecase_impl.dart';
import '../../domain/usecases/home/home_pattern_usecases.dart';
import '../../domain/usecases/home/home_project_usecases.dart';
import '../../domain/usecases/home/home_track_usecases.dart';

class HomeController extends ChangeNotifier {
  final TrackRepository _repository;
  final ProjectRepository _projectRepository;
  final ExportMidiUseCaseImpl _exportMidiUseCase;
  final AudioService _audioService = AudioService();

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  final Set<String> openedTracks = {};
  final Map<String, PatternSegment?> _trackSegments = {};
  final Map<String, PatternSegment> _savedSegments = {};

  HomeController(this._repository)
      : _projectRepository = ProjectRepository(),
        _exportMidiUseCase = ExportMidiUseCaseImpl();

  List<Track> get tracks => _repository.getTracks().cast<Track>();
  bool get isPlaying => _audioService.isPlaying;
  int get currentTick => _audioService.currentTick;

  int _playbackStartBar = 0;
  int get playbackStartBar => _playbackStartBar;

  PatternSegment? getTrackSegment(String trackId) => _trackSegments[trackId];

  void setTrackSegment(String trackId, PatternSegment segment) {
    _trackSegments[trackId] = segment;
    notifyListeners();
  }

  void clearTrackSegment(String trackId) {
    _trackSegments.remove(trackId);
    notifyListeners();
  }

  void saveSegment(PatternSegment segment) {
    _savedSegments[segment.id] = segment;
    notifyListeners();
  }

  List<PatternSegment> getSavedSegments() => _savedSegments.values.toList();

  void deleteSavedSegment(String segmentId) {
    _savedSegments.remove(segmentId);
    notifyListeners();
  }

  int get _ticksPerBar => AppConstants.ticksPerBar;

  void setPlaybackStartBar(int barIndex) {
    _playbackStartBar = barIndex.clamp(0, AppConstants.maxBars - 1);
    notifyListeners();
  }

  Track? _findTrack(String trackId) {
    try {
      return tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  PatternSegment? createSegmentFromBars(
    String trackId,
    int startBar,
    int barCount,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return null;

    return HomePatternUseCases.createSegmentFromBars(
      track: track,
      startBar: startBar,
      barCount: barCount,
      ticksPerBar: _ticksPerBar,
      savedSegmentCount: _savedSegments.length,
    );
  }

  void copySegmentToBar(
    String trackId,
    PatternSegment segment,
    int targetBarIndex,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return;

    final updatedNotes = HomePatternUseCases.copySegmentToBar(
      sourceNotes: track.notes,
      segment: segment,
      targetBarIndex: targetBarIndex,
      ticksPerBar: _ticksPerBar,
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
  }

  void deleteNotesInBar(String trackId, int barIndex) {
    final track = _findTrack(trackId);
    if (track == null) return;

    final updatedNotes = HomePatternUseCases.deleteNotesInBar(
      sourceNotes: track.notes,
      barIndex: barIndex,
      ticksPerBar: _ticksPerBar,
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
  }

  void addTrack() {
    _repository.addTrack(
      HomeTrackUseCases.createTrack(
        style: AppConstants.currentStyle,
        index: tracks.length,
      ),
    );
    notifyListeners();
  }

  Future<void> switchProjectStyle(ProjectStyleType styleType) async {
    final previousStyleType = AppConstants.currentStyleType;
    final previousStyle = AppConstants.currentStyle;

    if (previousStyleType == styleType) {
      AppConstants.applyProjectStyle(styleType);
      notifyListeners();
      return;
    }

    await saveProject(styleType: previousStyle.type);

    final loaded = await loadProject(styleType: styleType);
    if (!loaded) {
      createNewProject(styleType: styleType);
      await saveProject(styleType: styleType);
    } else {
      AppConstants.applyProjectStyle(styleType);
      notifyListeners();
    }
  }

  void createNewProject({
    required ProjectStyleType styleType,
  }) {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
    }

    AppConstants.resetProjectMetrics(styleType: styleType);

    final existingIds = tracks.map((t) => t.id).toList();
    for (final id in existingIds) {
      _repository.deleteTrack(id);
    }

    openedTracks.clear();
    _trackSegments.clear();
    _savedSegments.clear();
    _playbackStartBar = 0;

    final style = AppConstants.currentStyle;
    for (final track in HomeTrackUseCases.createStarterTracks(style)) {
      _repository.addTrack(track);
    }

    notifyListeners();
  }

  void deleteTrack(String id) {
    _repository.deleteTrack(id);
    openedTracks.remove(id);
    _trackSegments.remove(id);

    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
    }

    notifyListeners();
  }

  void toggleMute(String id) {
    _repository.toggleMute(id);
    notifyListeners();
  }

  void soloOrResetMute(String id) {
    final targetTrack = _findTrack(id);
    if (targetTrack == null) return;

    if (targetTrack.isMuted) {
      for (final track in tracks) {
        if (track.isMuted) {
          _repository.updateTrack(track.copyWith(isMuted: false));
        }
      }
      notifyListeners();
      return;
    }

    for (final track in tracks) {
      final shouldMute = track.id != id;
      if (track.isMuted != shouldMute) {
        _repository.updateTrack(track.copyWith(isMuted: shouldMute));
      }
    }

    notifyListeners();
  }

  void markAsOpened(String id) {
    openedTracks.add(id);
    notifyListeners();
  }

  void updateTrack(Track updatedTrack) {
    _repository.updateTrack(updatedTrack);
    notifyListeners();
  }

  void renameTrack(String id, String newName) {
    final track = _findTrack(id);
    if (track == null) return;

    _repository.updateTrack(track.copyWith(name: newName));
    notifyListeners();
  }

  void updateTrackInstrument(String id, String instrument) {
    final track = _findTrack(id);
    if (track == null) return;

    _repository.updateTrack(track.copyWith(instrument: instrument));
    notifyListeners();
  }

  void updateTrackVolume(String id, double volume) {
    final track = _findTrack(id);
    if (track == null) return;

    _repository.updateTrack(
      track.copyWith(volume: volume.clamp(0.0, 1.0)),
    );
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
      notifyListeners();
      return;
    }

    final tracksWithNotes =
        tracks.where((t) => !t.isMuted && t.notes.isNotEmpty).toList();

    if (tracksWithNotes.isEmpty) {
      debugPrint('⚠️ Нет дорожек с нотами для воспроизведения');
      return;
    }

    for (final track in tracksWithNotes) {
      await _audioService.setTrackInstrument(track.id, track.instrument);
    }

    final startTick = _playbackStartBar * AppConstants.ticksPerBar;

    _audioService.startPlayback(
      tracksWithNotes,
      startTick: startTick,
      onTick: notifyListeners,
      onFinished: notifyListeners,
    );

    notifyListeners();
  }

  void stopPlayback() {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
      notifyListeners();
    }
  }

  Future<void> exportMidi({
    required bool share,
    String? fileName,
    int bpm = 120,
  }) async {
    await _exportMidiUseCase.execute(
      tracks,
      share: share,
      fileName: fileName,
      bpm: bpm,
    );
  }

  Future<void> saveProject({ProjectStyleType? styleType}) async {
    final resolvedType = styleType ?? AppConstants.currentStyleType;
    final snapshot = HomeProjectUseCases.buildSnapshot(
      styleType: resolvedType,
      tracks: tracks,
    );

    await _projectRepository.save(snapshot, styleType: resolvedType);
  }

  Future<bool> loadProject({ProjectStyleType? styleType}) async {
    try {
      final snapshot = await _projectRepository.load(styleType: styleType);
      if (snapshot == null) return false;

      final loadedStyleType =
          HomeProjectUseCases.applySnapshotMetrics(snapshot);
      final loadedTracks = snapshot.tracks.whereType<Track>().toList();

      final existingIds = tracks.map((t) => t.id).toList();
      for (final id in existingIds) {
        _repository.deleteTrack(id);
      }

      if (loadedTracks.isEmpty) {
        createNewProject(styleType: loadedStyleType);
      } else {
        for (final track in loadedTracks) {
          _repository.addTrack(track);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Load project error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
    }

    horizontalScrollController.dispose();
    verticalScrollController.dispose();
    super.dispose();
  }
}
