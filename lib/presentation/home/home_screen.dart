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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBarWidth();
  }

  @override
  void dispose() {
    _segmentClearTimer?.cancel();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  void _calculateBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    AppConstants.barWidth = (screenWidth - 100) / 4;
  }

  void _openPianoRoll(Track track) {
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
      _showSnackBar('⚠️ В этом такте нет нот', Colors.orange);
      return;
    }

    _segmentClearTimer?.cancel();

    setState(() {
      _selectedSegment = segment;
      _selectedTrackId = track.id;
      _controller.setTrackSegment(track.id, segment);
    });

    _showSnackBar(
      '✅ Такт скопирован. Нажми на пустой такт для вставки или на заполненный для удаления',
      Colors.green,
      duration: const Duration(seconds: 2),
    );

    _segmentClearTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      setState(() {
        _clearSelectedSegment();
      });

      _showSnackBar('⌛ Выделение сегмента снято', Colors.grey);
    });
  }

  void _onBarTap(Track track, int barIndex) {
    final hasSegment = _selectedSegment != null && _selectedTrackId == track.id;

    if (hasSegment) {
      final notesInBar = _getNotesInBar(track, barIndex);
      final barHasNotes = notesInBar.isNotEmpty;

      if (barHasNotes) {
        _controller.deleteNotesInBar(track.id, barIndex);
        _showSnackBar('🗑️ Ноты в такте удалены', Colors.orange);
      } else {
        _controller.copySegmentToBar(track.id, _selectedSegment!, barIndex);
        _showSnackBar('📋 Сегмент вставлен', Colors.green);
      }

      setState(() {
        _clearSelectedSegment();
      });
      return;
    }

    _openPianoRoll(track);
  }

  void _clearSelectedSegment() {
    _segmentClearTimer?.cancel();
    if (_selectedTrackId != null) {
      _controller.clearTrackSegment(_selectedTrackId!);
    }
    _selectedSegment = null;
    _selectedTrackId = null;
  }

  void _showBpmSettings() {
    showDialog(
      context: context,
      builder: (context) {
        int tempBpm = AppConstants.bpm;
        int tempBars = AppConstants.totalBars;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              title: const Text(
                'Настройки проекта',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
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
                          setState(() {
                            tempBpm = (tempBpm - 5).clamp(40, 240);
                          });
                        },
                      ),
                      Expanded(
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
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.amber),
                        onPressed: () {
                          setState(() {
                            tempBpm = (tempBpm + 5).clamp(40, 240);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          setState(() {
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
                          setState(() {
                            tempBars = (tempBars + 1).clamp(1, 100);
                          });
                        },
                      ),
                    ],
                  ),
                ],
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
                    Navigator.pop(context);
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
              ? 'ZIP архив с MIDI файлами отправлен'
              : 'Папка с MIDI файлами сохранена',
          Colors.green,
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
        _controller.updateTrackInstrument(track.id, instrument);
        setState(() {});
      },
    );
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 2),
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

  void _scrollLeft() {
    if (_controller.horizontalScrollController.hasClients) {
      final newOffset = (_controller.horizontalScrollController.offset -
              AppConstants.barWidth)
          .clamp(
        0.0,
        _controller.horizontalScrollController.position.maxScrollExtent,
      );

      _controller.horizontalScrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollRight() {
    if (_controller.horizontalScrollController.hasClients) {
      final newOffset = (_controller.horizontalScrollController.offset +
              AppConstants.barWidth)
          .clamp(
        0.0,
        _controller.horizontalScrollController.position.maxScrollExtent,
      );

      _controller.horizontalScrollController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
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
    final playheadX =
        (_controller.currentTick * tickWidth) -
        (_controller.horizontalScrollController.hasClients
            ? _controller.horizontalScrollController.offset
            : 0);

    return Positioned(
      left: playheadX,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 3,
          color: Colors.amber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTracks = _controller.tracks.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
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
                GestureDetector(
                  onTap: _showBpmSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[850]?.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ShaderMask(
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
                        const Spacer(),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_controller.tracks.isEmpty) {
                                _showSnackBar(
                                  'Нет дорожек для воспроизведения',
                                  Colors.orange,
                                );
                                return;
                              }

                              final hasNotes = _controller.tracks
                                  .any((t) => t.notes.isNotEmpty);
                              if (!hasNotes) {
                                _showSnackBar(
                                  'Нет нот для воспроизведения',
                                  Colors.orange,
                                );
                                return;
                              }

                              _controller.togglePlayback();
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: Icon(
                              _controller.isPlaying
                                  ? Icons.stop
                                  : Icons.play_arrow,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: _saveProject,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Icon(Icons.save),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _exportToMidi(share: true),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Icon(Icons.share),
                        ),
                      ],
                    ),
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
                                controller: _controller.horizontalScrollController,
                                physics: const ClampingScrollPhysics(),
                                itemCount: AppConstants.maxBars,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: AppConstants.barWidth,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.amber,
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
                                  );
                                },
                              ),
                            ),
                            _buildPlayheadHeaderOverlay(),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _scrollLeft,
                                child: Container(
                                  width: 50,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _scrollRight,
                                child: Container(
                                  width: 50,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: hasTracks
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Scrollbar(
                            controller: _controller.verticalScrollController,
                            child: ListView.builder(
                              controller: _controller.verticalScrollController,
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
                                      _controller.toggleMute(track.id);
                                      setState(() {});
                                    },
                                    onEditPressed: () => _openPianoRoll(track),
                                    onDeletePressed: () {
                                      _controller.deleteTrack(track.id);
                                      setState(() {});
                                    },
                                    onRename: (newName) {
                                      _controller.renameTrack(track.id, newName);
                                      setState(() {});
                                    },
                                    onInstrumentChange: (instrument) {
                                      _controller.updateTrackInstrument(
                                        track.id,
                                        instrument,
                                      );
                                      setState(() {});
                                    },
                                    horizontalScrollController:
                                        _controller.horizontalScrollController,
                                    getNotesInBar: _getNotesInBar,
                                    getNoteRange: _getNoteRange,
                                    currentSegment: trackSegment,
                                    onBarLongPress: (barIndex) =>
                                        _onBarLongPress(track, barIndex),
                                    onBarTap: (barIndex) =>
                                        _onBarTap(track, barIndex),
                                    playheadTick: _controller.currentTick,
                                    isPlaying: _controller.isPlaying,
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : _buildEmptyState(),
                ),
                const SizedBox(height: 8),
              ],
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