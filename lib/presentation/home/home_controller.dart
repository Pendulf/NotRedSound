part of 'home_screen.dart';

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

  bool copySegmentToBar(
    String trackId,
    PatternSegment segment,
    int targetBarIndex,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return false;

    final targetStart = targetBarIndex * _ticksPerBar;
    final targetEnd = targetStart + (segment.barLength * _ticksPerBar);

    if (targetBarIndex < 0 ||
        targetStart < 0 ||
        targetStart >= AppConstants.maxTicks ||
        targetEnd > AppConstants.maxTicks) {
      return false;
    }

    final updatedNotes = HomePatternUseCases.copySegmentToBar(
      sourceNotes: track.notes,
      segment: segment,
      targetBarIndex: targetBarIndex,
      ticksPerBar: _ticksPerBar,
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
    return true;
  }

  bool deleteSegmentFromBars(
    String trackId,
    int startBar,
    int barCount,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return false;

    final safeBarCount = barCount.clamp(1, AppConstants.maxBars).toInt();
    final rangeStart = startBar * _ticksPerBar;
    final rangeEnd = rangeStart + (safeBarCount * _ticksPerBar);

    if (startBar < 0 ||
        rangeStart < 0 ||
        rangeStart >= AppConstants.maxTicks ||
        rangeEnd > AppConstants.maxTicks) {
      return false;
    }

    final updatedNotes = HomePatternUseCases.replaceNotesInRange(
      sourceNotes: track.notes,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      insertingNotes: const [],
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
    return true;
  }

  bool copyBarsToBarForTrack({
    required String trackId,
    required int startBar,
    required int barCount,
    required int targetBarIndex,
  }) {
    final track = _findTrack(trackId);
    if (track == null) return false;

    final safeBarCount = barCount.clamp(1, AppConstants.maxBars).toInt();
    final sourceStart = startBar * _ticksPerBar;
    final sourceEnd = sourceStart + (safeBarCount * _ticksPerBar);
    final targetStart = targetBarIndex * _ticksPerBar;
    final targetEnd = targetStart + (safeBarCount * _ticksPerBar);

    if (startBar < 0 ||
        targetBarIndex < 0 ||
        sourceStart < 0 ||
        sourceStart >= AppConstants.maxTicks ||
        sourceEnd > AppConstants.maxTicks ||
        targetStart < 0 ||
        targetStart >= AppConstants.maxTicks ||
        targetEnd > AppConstants.maxTicks) {
      return false;
    }

    final insertingNotes = HomePatternUseCases.copyNotesFromRange(
      sourceNotes: track.notes,
      sourceStart: sourceStart,
      sourceEnd: sourceEnd,
      targetStart: targetStart,
    );

    final updatedNotes = HomePatternUseCases.replaceNotesInRange(
      sourceNotes: track.notes,
      rangeStart: targetStart,
      rangeEnd: targetEnd,
      insertingNotes: insertingNotes,
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
    return true;
  }

  bool copyBarsToBar({
    required int startBar,
    required int barCount,
    required int targetBarIndex,
  }) {
    final safeBarCount = barCount.clamp(1, AppConstants.maxBars).toInt();
    final sourceStart = startBar * _ticksPerBar;
    final sourceEnd = sourceStart + (safeBarCount * _ticksPerBar);
    final targetStart = targetBarIndex * _ticksPerBar;
    final targetEnd = targetStart + (safeBarCount * _ticksPerBar);

    if (startBar < 0 ||
        targetBarIndex < 0 ||
        sourceStart < 0 ||
        sourceStart >= AppConstants.maxTicks ||
        sourceEnd > AppConstants.maxTicks ||
        targetStart < 0 ||
        targetStart >= AppConstants.maxTicks ||
        targetEnd > AppConstants.maxTicks) {
      return false;
    }

    final sourceTracks = List<Track>.from(tracks);

    for (final track in sourceTracks) {
      final insertingNotes = HomePatternUseCases.copyNotesFromRange(
        sourceNotes: track.notes,
        sourceStart: sourceStart,
        sourceEnd: sourceEnd,
        targetStart: targetStart,
      );

      final updatedNotes = HomePatternUseCases.replaceNotesInRange(
        sourceNotes: track.notes,
        rangeStart: targetStart,
        rangeEnd: targetEnd,
        insertingNotes: insertingNotes,
      );

      _repository.updateTrack(track.copyWith(notes: updatedNotes));
    }

    notifyListeners();
    return true;
  }

  bool deleteBarsFromAllTracks({
    required int startBar,
    required int barCount,
  }) {
    final safeBarCount = barCount.clamp(1, AppConstants.maxBars).toInt();
    final rangeStart = startBar * _ticksPerBar;
    final rangeEnd = rangeStart + (safeBarCount * _ticksPerBar);

    if (startBar < 0 ||
        rangeStart < 0 ||
        rangeStart >= AppConstants.maxTicks ||
        rangeEnd > AppConstants.maxTicks) {
      return false;
    }

    final sourceTracks = List<Track>.from(tracks);

    for (final track in sourceTracks) {
      final updatedNotes = HomePatternUseCases.replaceNotesInRange(
        sourceNotes: track.notes,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        insertingNotes: const [],
      );

      _repository.updateTrack(track.copyWith(notes: updatedNotes));
    }

    notifyListeners();
    return true;
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

class HomeUiController {
  final TrackRepository repository;
  final HomeController controller;

  HomeUiController({
    required this.repository,
    required this.controller,
  });

  int? selectedSegmentStartBar;
  int? selectedSegmentEndBar;
  String? selectedSegmentTrackId;
  bool isGlobalSegmentSelection = false;

  Timer? segmentClearTimer;
  Timer? _titlePulseTimer;
  bool titlePulseOn = false;

  final List<List<Track>> history = [];
  final List<List<Track>> redoHistory = [];

  bool canUndo(bool isPlaying) => history.isNotEmpty && !isPlaying;
  bool canRedo(bool isPlaying) => redoHistory.isNotEmpty && !isPlaying;

  List<Track> cloneTracks(List<Track> tracks) {
    return TrackSnapshotUtils.cloneTracks(tracks);
  }

  void pushHistory() {
    history.add(cloneTracks(controller.tracks));
    redoHistory.clear();

    if (history.length > 100) {
      history.removeAt(0);
    }
  }

  void restoreTracksFromSnapshot(List<Track> snapshot) {
    final repoTracks = repository.getTracks().cast<Track>();
    repoTracks
      ..clear()
      ..addAll(cloneTracks(snapshot));

    clearSelectedSegment();
  }

  List<Track>? undoSnapshot() {
    if (history.isEmpty || controller.isPlaying) return null;

    redoHistory.add(cloneTracks(controller.tracks));
    return history.removeLast();
  }

  List<Track>? redoSnapshot() {
    if (redoHistory.isEmpty || controller.isPlaying) return null;

    history.add(cloneTracks(controller.tracks));
    return redoHistory.removeLast();
  }

  int minBar(int a, int b) => a < b ? a : b;
  int maxBar(int a, int b) => a > b ? a : b;

  bool get hasDraftSegmentSelection =>
      selectedSegmentStartBar != null && selectedSegmentEndBar == null;

  bool get hasActiveSegmentSelection =>
      selectedSegmentStartBar != null && selectedSegmentEndBar != null;

  bool get hasAnySegmentSelection => selectedSegmentStartBar != null;

  bool get isTrackSegmentSelection =>
      hasAnySegmentSelection && !isGlobalSegmentSelection;

  bool get isTimelineSegmentSelection =>
      hasAnySegmentSelection && isGlobalSegmentSelection;

  int? get selectionRangeStartBar {
    if (selectedSegmentStartBar == null) return null;
    if (selectedSegmentEndBar == null) return selectedSegmentStartBar;
    return minBar(selectedSegmentStartBar!, selectedSegmentEndBar!)
        .clamp(0, AppConstants.maxBars - 1)
        .toInt();
  }

  int? get selectionRangeEndBar {
    if (selectedSegmentStartBar == null) return null;
    if (selectedSegmentEndBar == null) return selectedSegmentStartBar;
    return maxBar(selectedSegmentStartBar!, selectedSegmentEndBar!)
        .clamp(0, AppConstants.maxBars - 1)
        .toInt();
  }

  int get selectedBarCount {
    final startBar = selectionRangeStartBar;
    final endBar = selectionRangeEndBar;
    if (startBar == null || endBar == null) return 0;
    return endBar - startBar + 1;
  }

  bool isBarInSelection(int barIndex) {
    final startBar = selectionRangeStartBar;
    final endBar = selectionRangeEndBar;
    if (startBar == null || endBar == null) return false;
    return barIndex >= startBar && barIndex <= endBar;
  }

  bool isSelectionVisibleForTrack(Track track) {
    if (!hasAnySegmentSelection) return false;
    if (isGlobalSegmentSelection) return true;
    return selectedSegmentTrackId == track.id;
  }

  void beginSegmentSelection({
    required int barIndex,
    required bool isGlobal,
    String? trackId,
  }) {
    segmentClearTimer?.cancel();
    selectedSegmentStartBar =
        barIndex.clamp(0, AppConstants.maxBars - 1).toInt();
    selectedSegmentEndBar = null;
    selectedSegmentTrackId = isGlobal ? null : trackId;
    isGlobalSegmentSelection = isGlobal;
  }

  void finishSegmentSelection(int endBarIndex) {
    final rawStartBar = selectedSegmentStartBar;
    if (rawStartBar == null) return;

    selectedSegmentStartBar = minBar(rawStartBar, endBarIndex)
        .clamp(0, AppConstants.maxBars - 1)
        .toInt();
    selectedSegmentEndBar = maxBar(rawStartBar, endBarIndex)
        .clamp(0, AppConstants.maxBars - 1)
        .toInt();
  }

  void clearSelectedSegment() {
    segmentClearTimer?.cancel();
    selectedSegmentStartBar = null;
    selectedSegmentEndBar = null;
    selectedSegmentTrackId = null;
    isGlobalSegmentSelection = false;
  }

  void startTitlePulse({
    required bool Function() isPlaying,
    required void Function() onChanged,
  }) {
    if (_titlePulseTimer != null) return;

    titlePulseOn = true;
    final beatMs = (60000 / AppConstants.bpm).round();

    _titlePulseTimer = Timer.periodic(Duration(milliseconds: beatMs), (_) {
      if (!isPlaying()) {
        stopTitlePulse(onChanged: onChanged);
        return;
      }

      titlePulseOn = !titlePulseOn;
      onChanged();
    });
  }

  void stopTitlePulse({void Function()? onChanged}) {
    _titlePulseTimer?.cancel();
    _titlePulseTimer = null;
    titlePulseOn = false;
    onChanged?.call();
  }

  void dispose() {
    segmentClearTimer?.cancel();
    _titlePulseTimer?.cancel();
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late HomeController _controller;
  late TrackRepository _repository;
  late HomeUiController _uiState;

  int? get _selectedSegmentStartBar => _uiState.selectedSegmentStartBar;
  set _selectedSegmentStartBar(int? value) =>
      _uiState.selectedSegmentStartBar = value;

  int? get _selectedSegmentEndBar => _uiState.selectedSegmentEndBar;
  set _selectedSegmentEndBar(int? value) =>
      _uiState.selectedSegmentEndBar = value;

  String? get _selectedSegmentTrackId => _uiState.selectedSegmentTrackId;
  set _selectedSegmentTrackId(String? value) =>
      _uiState.selectedSegmentTrackId = value;

  bool get _isGlobalSegmentSelection => _uiState.isGlobalSegmentSelection;
  set _isGlobalSegmentSelection(bool value) =>
      _uiState.isGlobalSegmentSelection = value;

  Timer? get _segmentClearTimer => _uiState.segmentClearTimer;
  bool get _titlePulseOn => _uiState.titlePulseOn;

  List<List<Track>> get _history => _uiState.history;
  List<List<Track>> get _redoHistory => _uiState.redoHistory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = TrackRepository();
    _controller = HomeController(_repository);
    _uiState = HomeUiController(
      repository: _repository,
      controller: _controller,
    );
    _controller.addListener(_controllerListener);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _calculateBarWidth();

      if (widget.loadSavedProject) {
        final loaded = await _controller.loadProject(
          styleType: widget.initialStyleType,
        );
        if (!loaded) {
          _controller.createNewProject(styleType: widget.initialStyleType);
        }
      } else {
        _controller.createNewProject(styleType: widget.initialStyleType);
      }

      if (mounted) {
        _safeSetHomeState(() {});
      }
    });
  }

  void _controllerListener() {
    if (!mounted) return;

    if (_controller.isPlaying) {
      _startTitlePulse();
    } else {
      _stopTitlePulse();
    }

    _safeSetHomeState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBarWidth();
  }

  @override
  void dispose() {
    _uiState.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.stopPlayback();
      _stopTitlePulse();
    }
  }

  bool get _canUndo => _uiState.canUndo(_controller.isPlaying);
  bool get _canRedo => _uiState.canRedo(_controller.isPlaying);

  void _startTitlePulse() {
    _uiState.startTitlePulse(
      isPlaying: () => mounted && _controller.isPlaying,
      onChanged: () {
        if (mounted) _safeSetHomeState(() {});
      },
    );
  }

  void _stopTitlePulse() {
    _uiState.stopTitlePulse(
      onChanged: () {
        if (mounted) _safeSetHomeState(() {});
      },
    );
  }

  void _calculateBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    AppConstants.updateBarWidthForScreen(screenWidth);
  }

  Map<String, int> _getNoteRange(Track track) {
    return BarNoteService.noteRange(track).toMap();
  }

  void _safeSetHomeState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  @override
  Widget build(BuildContext context) =>
      _HomeScreenLogic(this).buildHomeScreenContent(context);
}

extension _HomeScreenActions on _HomeScreenState {
  void _pushHistory() => _uiState.pushHistory();

  void _restoreTracksFromSnapshot(List<Track> snapshot) {
    _uiState.restoreTracksFromSnapshot(snapshot);
    _safeSetHomeState(() {});
  }

  void _undoLastAction() {
    final snapshot = _uiState.undoSnapshot();
    if (snapshot == null) return;
    _restoreTracksFromSnapshot(snapshot);
  }

  void _redoLastAction() {
    final snapshot = _uiState.redoSnapshot();
    if (snapshot == null) return;
    _restoreTracksFromSnapshot(snapshot);
  }

  void _openPianoRoll(Track track, {int initialBar = 0}) {
    if (_controller.isPlaying) {
      _controller.stopPlayback();
      _stopTitlePulse();
    }

    _controller.markAsOpened(track.id);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PianoRollScreen(
          track: track,
          onTrackUpdated: (updatedTrack) {
            _controller.updateTrack(updatedTrack);
          },
          bpm: AppConstants.bpm,
          initialStartTick: initialBar * AppConstants.ticksPerBar,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _safeSetHomeState(() {});
      }
    });
  }

  bool get _hasDraftSegmentSelection => _uiState.hasDraftSegmentSelection;

  bool get _hasActiveSegmentSelection => _uiState.hasActiveSegmentSelection;

  bool get _hasAnySegmentSelection => _uiState.hasAnySegmentSelection;

  bool get _isTrackSegmentSelection => _uiState.isTrackSegmentSelection;

  bool get _isTimelineSegmentSelection => _uiState.isTimelineSegmentSelection;

  int? get _selectionRangeStartBar => _uiState.selectionRangeStartBar;

  int get _selectedBarCount => _uiState.selectedBarCount;

  bool _isBarInSelection(int barIndex) => _uiState.isBarInSelection(barIndex);

  bool _isSelectionVisibleForTrack(Track track) {
    return _uiState.isSelectionVisibleForTrack(track);
  }

  void _beginSegmentSelection({
    required int barIndex,
    required bool isGlobal,
    String? trackId,
  }) {
    if (_controller.isPlaying) return;

    _safeSetHomeState(() {
      _uiState.beginSegmentSelection(
        barIndex: barIndex,
        isGlobal: isGlobal,
        trackId: trackId,
      );
    });
  }

  void _onTimelineLongPress(int barIndex) {
    _beginSegmentSelection(
      barIndex: barIndex,
      isGlobal: true,
    );
  }

  void _onTimelineTap(int barIndex) {
    if (_controller.isPlaying) return;

    if (_hasDraftSegmentSelection) {
      if (_isTimelineSegmentSelection) {
        _finishSegmentSelection(barIndex);
      }
      return;
    }

    if (_hasActiveSegmentSelection) {
      if (_isTimelineSegmentSelection) {
        _copySelectedBarsToBar(barIndex);
      }
      return;
    }

    _controller.setPlaybackStartBar(barIndex);
  }

  void _onBarLongPress(Track track, int barIndex) {
    _beginSegmentSelection(
      barIndex: barIndex,
      isGlobal: false,
      trackId: track.id,
    );
  }

  void _onBarTap(Track track, int barIndex) {
    if (_hasDraftSegmentSelection) {
      if (_isTrackSegmentSelection && _selectedSegmentTrackId == track.id) {
        _finishSegmentSelection(barIndex);
      }
      return;
    }

    if (_hasActiveSegmentSelection) {
      if (_isTrackSegmentSelection && _selectedSegmentTrackId == track.id) {
        _copySelectedBarsToBar(barIndex);
      }
      return;
    }

    _openPianoRoll(track, initialBar: barIndex);
  }

  void _finishSegmentSelection(int endBarIndex) {
    _safeSetHomeState(() {
      _uiState.finishSegmentSelection(endBarIndex);
    });
  }

  void _copySelectedBarsToBar(int targetBarIndex) {
    final startBar = _selectionRangeStartBar;
    final barCount = _selectedBarCount;

    if (startBar == null || barCount <= 0) return;

    _pushHistory();

    final bool copied;
    if (_isGlobalSegmentSelection) {
      copied = _controller.copyBarsToBar(
        startBar: startBar,
        barCount: barCount,
        targetBarIndex: targetBarIndex,
      );
    } else {
      final trackId = _selectedSegmentTrackId;
      if (trackId == null) {
        _history.removeLast();
        return;
      }

      copied = _controller.copyBarsToBarForTrack(
        trackId: trackId,
        startBar: startBar,
        barCount: barCount,
        targetBarIndex: targetBarIndex,
      );
    }

    if (!copied) {
      _history.removeLast();
      return;
    }

    _safeSetHomeState(() {
      _clearSelectedSegment();
    });
  }

  void _deleteSelectedSegmentFromSource() {
    final startBar = _selectionRangeStartBar;
    final barCount = _selectedBarCount;

    if (startBar == null || barCount <= 0) return;

    _pushHistory();

    final bool deleted;
    if (_isGlobalSegmentSelection) {
      deleted = _controller.deleteBarsFromAllTracks(
        startBar: startBar,
        barCount: barCount,
      );
    } else {
      final trackId = _selectedSegmentTrackId;
      if (trackId == null) {
        _history.removeLast();
        return;
      }

      deleted = _controller.deleteSegmentFromBars(
        trackId,
        startBar,
        barCount,
      );
    }

    if (!deleted) {
      _history.removeLast();
      return;
    }

    _safeSetHomeState(() {
      _clearSelectedSegment();
    });
  }

  void _clearSelectedSegment() {
    _uiState.clearSelectedSegment();
  }

  int _roundToNearestFive(int value) {
    return ((value / 5).round() * 5).clamp(40, 240);
  }

  void _deleteCurrentProject() {
    _pushHistory();

    if (_controller.isPlaying) {
      _controller.togglePlayback();
    }

    final repoTracks = List<Track>.from(_repository.getTracks().cast<Track>());

    for (final track in repoTracks) {
      _controller.updateTrack(
        track.copyWith(
          notes: [],
        ),
      );
    }

    _clearSelectedSegment();
    _safeSetHomeState(() {});
    _showSnackBar('Проект очищен', Colors.red);
  }

  Future<void> _saveProject() async {
    try {
      await _controller.saveProject();
      if (!mounted) return;
      _showSnackBar('Проект сохранён', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Ошибка сохранения: $e', Colors.red);
    }
  }

  Future<void> _exportToMidi({required bool share}) async {
    if (_controller.tracks.isEmpty) {
      _showSnackBar('Нет дорожек для экспорта', Colors.red);
      return;
    }

    String? fileName;
    if (_controller.tracks.length == 1) {
      fileName = '${_controller.tracks.first.name}.mid';
    }

    _showLoadingDialog();

    try {
      await _controller.exportMidi(
        share: share,
        fileName: fileName,
        bpm: AppConstants.bpm,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar(
        share ? 'MIDI файл отправлен' : 'MIDI файл сохранён',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Ошибка экспорта: $e', Colors.red);
    }
  }

  void _handleTrackPreviewHorizontalDrag(DragUpdateDetails details) {
    if (!_controller.horizontalScrollController.hasClients) return;

    final delta = details.primaryDelta ?? 0.0;
    final position = _controller.horizontalScrollController.position;

    final newOffset =
        (_controller.horizontalScrollController.offset - delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _controller.horizontalScrollController.jumpTo(newOffset);
  }

  List<MidiNote> _getNotesInBar(Track track, int barIndex) {
    return BarNoteService.notesInBar(
      track: track,
      barIndex: barIndex,
      ticksPerBar: AppConstants.ticksPerBar,
    )
        .map(
          (note) => MidiNote(
            pitch: note.pitch,
            startTick: note.startTick,
            durationTicks: note.durationTicks,
          ),
        )
        .toList();
  }
}
