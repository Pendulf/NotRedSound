import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/dialogs/instrument_picker_dialog.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/track_repository.dart';
import '../piano_roll/piano_roll_screen.dart';
import 'home_controller.dart';
import 'widgets/track_row_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeController _controller;
  late TrackRepository _repository;

  PatternSegment? _selectedSegment;
  String? _selectedTrackId;
  Timer? _segmentClearTimer;

  Timer? _titlePulseTimer;
  bool _titlePulseOn = false;

  final List<List<Track>> _history = [];

  @override
  void initState() {
    super.initState();
    _repository = TrackRepository();
    _controller = HomeController(_repository);
    _controller.addListener(_controllerListener);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _calculateBarWidth();
      await _controller.loadProject();
      if (mounted) {
        setState(() {});
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

    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBarWidth();
  }

  @override
  void dispose() {
    _segmentClearTimer?.cancel();
    _titlePulseTimer?.cancel();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  List<MidiNote> _cloneNotes(List<MidiNote> notes) {
    return notes
        .map(
          (n) => MidiNote(
            pitch: n.pitch,
            startTick: n.startTick,
            durationTicks: n.durationTicks,
          ),
        )
        .toList();
  }

  Track _cloneTrack(Track track) {
    return track.copyWith(
      notes: _cloneNotes(track.notes),
    );
  }

  List<Track> _cloneTracks(List<Track> tracks) {
    return tracks.map(_cloneTrack).toList();
  }

  void _pushHistory() {
    _history.add(_cloneTracks(_controller.tracks));
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  bool get _canUndo => _history.isNotEmpty && !_controller.isPlaying;

  void _restoreTracksFromSnapshot(List<Track> snapshot) {
    final repoTracks = _repository.getTracks().cast<Track>();
    repoTracks
      ..clear()
      ..addAll(_cloneTracks(snapshot));

    _clearSelectedSegment();
    setState(() {});
  }

  void _undoLastAction() {
    if (!_canUndo) return;
    final snapshot = _history.removeLast();
    _restoreTracksFromSnapshot(snapshot);
  }

  void _startTitlePulse() {
    if (_titlePulseTimer != null) return;

    _titlePulseOn = true;
    final beatMs = (60000 / AppConstants.bpm).round();

    _titlePulseTimer = Timer.periodic(Duration(milliseconds: beatMs), (_) {
      if (!mounted || !_controller.isPlaying) {
        _stopTitlePulse();
        return;
      }

      setState(() {
        _titlePulseOn = !_titlePulseOn;
      });
    });
  }

  void _stopTitlePulse() {
    _titlePulseTimer?.cancel();
    _titlePulseTimer = null;
    _titlePulseOn = false;
  }

  void _calculateBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    AppConstants.barWidth = (screenWidth - 100) / 4;
  }

  void _openPianoRoll(Track track, {int initialBar = 0}) {
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
        setState(() {});
      }
    });
  }

  void _onBarLongPress(Track track, int barIndex) {
    final segment = _controller.createSegmentFromBars(track.id, barIndex, 1);

    if (segment == null) {
      _showSnackBar('В этом такте нет нот', Colors.orange);
      return;
    }

    _segmentClearTimer?.cancel();

    setState(() {
      _selectedSegment = segment;
      _selectedTrackId = track.id;
      _controller.setTrackSegment(track.id, segment);
    });

    _segmentClearTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      setState(() {
        _clearSelectedSegment();
      });
    });
  }

  void _onBarTap(Track track, int barIndex) {
    final hasSegment = _selectedSegment != null && _selectedTrackId == track.id;

    if (hasSegment) {
      final notesInBar = _getNotesInBar(track, barIndex);
      final barHasNotes = notesInBar.isNotEmpty;

      _pushHistory();

      if (barHasNotes) {
        _controller.deleteNotesInBar(track.id, barIndex);
      } else {
        _controller.copySegmentToBar(track.id, _selectedSegment!, barIndex);
      }

      setState(() {
        _clearSelectedSegment();
      });
      return;
    }

    _openPianoRoll(track, initialBar: barIndex);
  }

  void _clearSelectedSegment() {
    _segmentClearTimer?.cancel();
    if (_selectedTrackId != null) {
      _controller.clearTrackSegment(_selectedTrackId!);
    }
    _selectedSegment = null;
    _selectedTrackId = null;
  }

  int _roundToNearestFive(int value) {
    return ((value / 5).round() * 5).clamp(40, 240);
  }

  void _showProjectPopup() {
    showDialog(
      context: context,
      builder: (context) {
        int tempBpm = AppConstants.bpm;
        int tempBars = AppConstants.totalBars;
        int tempBeatsPerBar = AppConstants.beatsPerBar;

        DateTime? lastTapTime;
        final List<int> tapIntervalsMs = [];

        void handleTapTempo(void Function(void Function()) setLocalState) {
          final now = DateTime.now();

          if (lastTapTime == null) {
            lastTapTime = now;
            return;
          }

          final diff = now.difference(lastTapTime!).inMilliseconds;
          lastTapTime = now;

          if (diff < 120 || diff > 2000) {
            tapIntervalsMs.clear();
            return;
          }

          tapIntervalsMs.add(diff);

          if (tapIntervalsMs.length > 6) {
            tapIntervalsMs.removeAt(0);
          }

          final averageMs =
              tapIntervalsMs.reduce((a, b) => a + b) / tapIntervalsMs.length;

          final calculatedBpm =
              _roundToNearestFive((60000 / averageMs).round());

          setLocalState(() {
            tempBpm = calculatedBpm;
          });
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.deepPurple, width: 1.2),
              ),
              title: const Text(
                'Проект',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Темп (BPM)',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBpm = (tempBpm - 5).clamp(40, 240);
                            });
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: () => handleTapTempo(setLocalState),
                              child: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '$tempBpm',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBpm = (tempBpm + 5).clamp(40, 240);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Количество тактов',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBars = (tempBars - 1).clamp(1, 100);
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            '$tempBars',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBars = (tempBars + 1).clamp(1, 100);
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.save, color: Colors.green),
                      title: const Text(
                        'Сохранить проект',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        AppConstants.updateBpm(tempBpm);
                        AppConstants.updateTotalBars(tempBars);
                        AppConstants.updateTimeSignature(
                          newBeatsPerBar: tempBeatsPerBar,
                        );
                        _calculateBarWidth();
                        Navigator.pop(context);
                        setState(() {});
                        _saveProject();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.share, color: Colors.blue),
                      title: const Text(
                        'Отправить проект',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        AppConstants.updateBpm(tempBpm);
                        AppConstants.updateTotalBars(tempBars);
                        AppConstants.updateTimeSignature(
                          newBeatsPerBar: tempBeatsPerBar,
                        );
                        _calculateBarWidth();
                        Navigator.pop(context);
                        setState(() {});
                        _exportToMidi(share: true);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Удалить проект',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteProject();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    AppConstants.updateBpm(tempBpm);
                    AppConstants.updateTotalBars(tempBars);
                    AppConstants.updateTimeSignature(
                      newBeatsPerBar: tempBeatsPerBar,
                    );
                    Navigator.pop(context);
                    _calculateBarWidth();
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1.2),
        ),
        title: const Text(
          'Удалить текущий проект',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Все дорожки текущего проекта будут удалены. Продолжить?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCurrentProject();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _deleteCurrentProject() {
    _pushHistory();

    final repoTracks = _repository.getTracks().cast<Track>();
    repoTracks.clear();

    _clearSelectedSegment();

    setState(() {});
    _showSnackBar('Текущий проект удалён', Colors.red);
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

      if (_controller.tracks.length == 1 && fileName != null) {
        _showSnackBar(
          share ? 'MIDI файл отправлен' : 'MIDI файл сохранён',
          Colors.green,
        );
      } else {
        _showSnackBar(
          share
              ? 'ZIP архив с MIDI файлами не отправлен'
              : 'Папка с MIDI файлами не сохранена',
          Colors.orange,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('Ошибка: $e', Colors.red);
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }

  void _showInstrumentPickerForTrack(Track track) {
    showInstrumentPickerDialog(
      context,
      track,
      (instrument) {
        _pushHistory();
        _controller.updateTrackInstrument(track.id, instrument);
        setState(() {});
      },
    );
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 1),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
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
    final startTick = barIndex * AppConstants.ticksPerBar;
    final endTick = startTick + AppConstants.ticksPerBar;

    final result = <MidiNote>[];

    for (final note in track.notes) {
      if (!note.intersectsRange(startTick, endTick)) continue;

      final clippedStart =
          note.startTick < startTick ? startTick : note.startTick;
      final clippedEnd = note.endTick > endTick ? endTick : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      result.add(
        MidiNote(
          pitch: note.pitch,
          startTick: clippedStart - startTick,
          durationTicks: clippedDuration,
        ),
      );
    }

    result.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });

    return result;
  }

  Map<String, int> _getNoteRange(Track track) {
    if (track.notes.isEmpty) {
      return {'min': 48, 'max': 84};
    }

    int minPitch = track.notes.first.pitch;
    int maxPitch = track.notes.first.pitch;

    for (final note in track.notes) {
      if (note.pitch < minPitch) minPitch = note.pitch;
      if (note.pitch > maxPitch) maxPitch = note.pitch;
    }

    minPitch = (minPitch - 2).clamp(0, 127);
    maxPitch = (maxPitch + 2).clamp(0, 127);

    return {'min': minPitch, 'max': maxPitch};
  }

  Widget _buildPlayheadHeaderOverlay() {
    if (!_controller.isPlaying) {
      return const SizedBox.shrink();
    }

    final tickWidth = AppConstants.barWidth / AppConstants.ticksPerBar;
    final playheadX = (_controller.currentTick * tickWidth) -
        (_controller.horizontalScrollController.hasClients
            ? _controller.horizontalScrollController.offset
            : 0);

    return Positioned(
      left: playheadX,
      top: 10,
      bottom: 10,
      child: IgnorePointer(
        child: Container(
          width: 3,
          color: Colors.amber,
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle() {
    final pulseDuration = Duration(
      milliseconds: (60000 / AppConstants.bpm / 2).round(),
    );

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedScale(
          scale: _controller.isPlaying ? (_titlePulseOn ? 1.12 : 1.0) : 1.0,
          duration: pulseDuration,
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: _controller.isPlaying ? (_titlePulseOn ? 1.0 : 0.82) : 1.0,
            duration: pulseDuration,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.red, Colors.purple, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'NotRed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 24,
        icon: Icon(
          icon,
          color: Colors.white.withValues(alpha: onPressed == null ? 0.4 : 1.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTracks = _controller.tracks.isNotEmpty;
    final selectedBar = _controller.isPlaying
        ? -1
        : _controller.playbackStartBar.clamp(0, AppConstants.maxBars - 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/electro_background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[900]);
              },
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.horizontalPadding,
            ),
            child: Column(
              children: [
                const SizedBox(height: 35),
                Container(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 123, 36, 29)
                            .withValues(alpha: 0.60), // прозрачность градиента
                        const Color.fromARGB(255, 109, 29, 123)
                            .withValues(alpha: 0.60),
                        const Color.fromARGB(255, 19, 112, 175)
                            .withValues(alpha: 0.60),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildAnimatedTitle(),
                        ),
                      ),
                      Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    gradient: LinearGradient(
      colors: [
        Colors.red.withValues(alpha: 0.18),
        Colors.purple.withValues(alpha: 0.18),
        Colors.blue.withValues(alpha: 0.18),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    
    boxShadow: [
      BoxShadow(
        color: Colors.red.withValues(alpha: 0.10),
        blurRadius: 10,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Colors.purple.withValues(alpha: 0.10),
        blurRadius: 14,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Colors.blue.withValues(alpha: 0.10),
        blurRadius: 18,
        spreadRadius: 2,
      ),
    ],
  ),
  child: Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: _showProjectPopup,
      child: Container(
        width: 52,
        height: 52,
        
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withValues(alpha: 0.82),
                
              ),
            ),
            const Icon(
              Icons.menu,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    ),
  ),
),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (hasTracks) ...[
                  Row(
                    children: [
                      Container(
                        width: 200,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _pushHistory();
                              _controller.addTrack();
                              setState(() {});
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final lastTrack = _controller.tracks.last;
                                _showInstrumentPickerForTrack(lastTrack);
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Добавить дорожку',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[850]?.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                controller:
                                    _controller.horizontalScrollController,
                                physics: const ClampingScrollPhysics(),
                                itemCount: AppConstants.maxBars,
                                itemBuilder: (context, index) {
                                  final isSelected = selectedBar == index;

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        _controller.setPlaybackStartBar(index),
                                    child: Container(
                                      width: AppConstants.barWidth,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.amber
                                                .withValues(alpha: 0.18)
                                            : Colors.transparent,
                                        border: Border(
                                          right: BorderSide(
                                            color: index ==
                                                    AppConstants.maxBars - 1
                                                ? Colors.transparent
                                                : Colors.amber,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            _buildPlayheadHeaderOverlay(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: hasTracks
                      ? GestureDetector(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Scrollbar(
                              controller: _controller.verticalScrollController,
                              child: ListView.builder(
                                controller:
                                    _controller.verticalScrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _controller.tracks.length,
                                itemBuilder: (context, index) {
                                  final track = _controller.tracks[index];
                                  final trackSegment =
                                      _selectedTrackId == track.id
                                          ? _selectedSegment
                                          : null;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: TrackRowWidget(
                                      track: track,
                                      hasBeenOpened: _controller.openedTracks
                                          .contains(track.id),
                                      onMutePressed: () {
                                        _pushHistory();
                                        _controller.toggleMute(track.id);
                                        setState(() {});
                                      },
                                      onMuteLongPressed: () {
                                        _pushHistory();
                                        _controller.soloOrResetMute(track.id);
                                        setState(() {});
                                      },
                                      onEditPressed: () =>
                                          _openPianoRoll(track),
                                      onDeletePressed: () {
                                        _pushHistory();
                                        _controller.deleteTrack(track.id);
                                        setState(() {});
                                      },
                                      onRename: (newName) {
                                        _pushHistory();
                                        _controller.renameTrack(
                                            track.id, newName);
                                        setState(() {});
                                      },
                                      onInstrumentChange: (instrument) {
                                        _pushHistory();
                                        _controller.updateTrackInstrument(
                                          track.id,
                                          instrument,
                                        );
                                        setState(() {});
                                      },
                                      onVolumeChanged: (value) {
                                        _pushHistory();
                                        _controller.updateTrackVolume(
                                          track.id,
                                          value,
                                        );
                                        setState(() {});
                                      },
                                      horizontalScrollController: _controller
                                          .horizontalScrollController,
                                      getNotesInBar: _getNotesInBar,
                                      getNoteRange: _getNoteRange,
                                      currentSegment: trackSegment,
                                      onBarLongPress: (barIndex) =>
                                          _onBarLongPress(track, barIndex),
                                      onBarTap: (barIndex) =>
                                          _onBarTap(track, barIndex),
                                      playheadTick: _controller.currentTick,
                                      isPlaying: _controller.isPlaying,
                                      onHorizontalPreviewDrag:
                                          _handleTrackPreviewHorizontalDrag,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : _buildEmptyState(),
                ),
                const SizedBox(height: 85),
              ],
            ),
          ),
          if (hasTracks)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.horizontalPadding,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple,
                        ),
                        child: IconButton(
                          onPressed: _canUndo ? _undoLastAction : null,
                          padding: EdgeInsets.zero,
                          splashRadius: 26,
                          icon: Icon(
                            Icons.undo,
                            size: 22,
                            color: Colors.white.withValues(
                              alpha: _canUndo ? 1.0 : 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple,
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (_controller.tracks.isEmpty) {
                              _showSnackBar(
                                'Добавьте дорожку',
                                Colors.orange,
                              );
                              return;
                            }

                            final hasNotes = _controller.tracks
                                .any((t) => t.notes.isNotEmpty);

                            if (!hasNotes) {
                              _showSnackBar(
                                'Добавьте ноты',
                                Colors.orange,
                              );
                              return;
                            }

                            _controller.togglePlayback();
                            setState(() {});
                          },
                          padding: EdgeInsets.zero,
                          splashRadius: 30,
                          icon: Icon(
                            _controller.isPlaying
                                ? Icons.stop
                                : Icons.play_arrow,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Icon(Icons.queue_music, size: 60, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет дорожек',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте первую дорожку, чтобы начать',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _pushHistory();
              _controller.addTrack();
              setState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final lastTrack = _controller.tracks.last;
                _showInstrumentPickerForTrack(lastTrack);
              });
            },
            icon: const Icon(Icons.add, size: 24),
            label: const Text(
              'Создать дорожку',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
