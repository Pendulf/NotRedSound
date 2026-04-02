import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/repositories/track_repository.dart';
import '../piano_roll/piano_roll_screen.dart';
import '../../core/constants/app_constants.dart';
import 'home_controller.dart';
import 'widgets/track_row_widget.dart';
import '../../core/dialogs/instrument_picker_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeController _controller;
  late TrackRepository _repository;
  
  // Состояние для сегментов
  PatternSegment? _selectedSegment;
  String? _selectedTrackId;
  Timer? _segmentClearTimer;

  @override
  void initState() {
    super.initState();
    _repository = TrackRepository();
    _controller = HomeController(_repository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateBarWidth();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBarWidth();
  }

  @override
  void dispose() {
    _segmentClearTimer?.cancel();
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
      setState(() {});
    });
  }

  // Обработка долгого нажатия на такт
  void _onBarLongPress(Track track, int barIndex) {
    // Создаем сегмент из текущего такта
    final segment = _controller.createSegmentFromBars(track.id, barIndex, 1);
    
    if (segment != null) {
      // Отменяем предыдущий таймер если есть
      _segmentClearTimer?.cancel();
      
      setState(() {
        _selectedSegment = segment;
        _selectedTrackId = track.id;
        _controller.setTrackSegment(track.id, segment);
      });
      
      _showSnackBar(
        '✅ Сегмент создан! Нажмите на пустой такт для вставки',
        Colors.green,
        duration: const Duration(seconds: 2),
      );
      
      // Автоматически снимаем выделение через 3 секунды
      _segmentClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _selectedSegment != null) {
          setState(() {
            _clearSelectedSegment();
          });
          _showSnackBar('⌛️ Выделение сегмента снято', Colors.grey);
        }
      });
    } else {
      _showSnackBar('⚠️ Нет нот в этом такте', Colors.orange);
    }
  }

// Обработка нажатия на такт
void _onBarTap(Track track, int barIndex) {
  final notesInBar = _getNotesInBar(track, barIndex);
  final hasNotes = notesInBar.isNotEmpty;
  final hasSegment = _selectedSegment != null && _selectedTrackId == track.id;
  
  // Если есть выделенный сегмент
  if (hasSegment) {
    if (hasNotes) {
      // Если такт заполнен - удаляем ноты в этом такте
      _deleteNotesInBar(track, barIndex);
      
      // Снимаем выделение сегмента
      setState(() {
        _clearSelectedSegment();
      });
    } else {
      // Если такт пустой - вставляем сегмент
      _controller.copySegmentToBar(track.id, _selectedSegment!, barIndex);

      setState(() {
        _clearSelectedSegment();
      });
    }
  } else {

    _openPianoRoll(track);
  }
}
  
  // Удаление нот в конкретном такте
  void _deleteNotesInBar(Track track, int barIndex) {
    final ticksPerBar = AppConstants.ticksPerBeat * AppConstants.beatsPerBar;
    final startTick = barIndex * ticksPerBar;
    final endTick = (barIndex + 1) * ticksPerBar;
    
    // Фильтруем ноты, удаляя те, что находятся в указанном такте
    final updatedNotes = track.notes
        .where((note) => note.startTick < startTick || note.startTick >= endTick)
        .toList();
    
    // Обновляем дорожку
    final updatedTrack = Track(
      id: track.id,
      name: track.name,
      isMuted: track.isMuted,
      color: track.color,
      notes: updatedNotes,
      instrument: track.instrument,
    );
    
    _controller.updateTrack(updatedTrack);
  }
  
  // Очистка выбранного сегмента
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
                    setState(() {});
                    Navigator.pop(context);
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
    _showSnackBar('Функция в разработке', Colors.orange);
  }

  Future<void> _exportToMidi({required bool share}) async {
    if (_controller.tracks.isEmpty) {
      _showSnackBar('Нет дорожек для экспорта', Colors.red);
      return;
    }

    String? fileName;
    if (_controller.tracks.length == 1) {
      final trackName = _controller.tracks.first.name;
      fileName = '$trackName.mid';
    }

    _showLoadingDialog();

    try {
      await _controller.exportMidi(
        share: share,
        fileName: fileName,
        bpm: AppConstants.bpm,
      );

      if (context.mounted) {
        Navigator.pop(context);

        String successMessage;
        if (_controller.tracks.length == 1 && fileName != null) {
          successMessage = share
              ? 'MIDI файл "${fileName.replaceAll('.mid', '')}" отправлен'
              : 'MIDI файл "${fileName.replaceAll('.mid', '')}" сохранен в Downloads';
        } else {
          if (share) {
            successMessage = 'ZIP архив с MIDI файлами отправлен';
          } else {
            successMessage = 'Папка с MIDI файлами сохранена в Downloads/NotRed_Export_*';
          }
        }

        _showSnackBar(successMessage, Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar('Ошибка: ${e.toString()}', Colors.red);
      }
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

  void _showSnackBar(String message, Color color, {Duration duration = const Duration(seconds: 2)}) {
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  List<MidiNote> _getNotesInBar(Track track, int barIndex) {
    final ticksPerBar = AppConstants.ticksPerBeat * AppConstants.beatsPerBar;
    final startTick = barIndex * ticksPerBar;
    final endTick = (barIndex + 1) * ticksPerBar;

    return track.notes
        .where(
          (note) =>
              (note.startTick >= startTick && note.startTick < endTick) ||
              (note.startTick + note.durationTicks > startTick &&
                  note.startTick < endTick),
        )
        .toList();
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

  @override
  Widget build(BuildContext context) {
    final bool hasTracks = _controller.tracks.isNotEmpty;

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
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.horizontalPadding,
            ),
            child: Column(
              children: [
                const SizedBox(height: 35),

                // AppBar
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
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.purple,
                              Colors.blue,
                            ],
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
                                _showSnackBar('Нет дорожек для воспроизведения',
                                    Colors.orange);
                                return;
                              }
                              final hasNotes = _controller.tracks
                                  .any((t) => t.notes.isNotEmpty);
                              if (!hasNotes) {
                                _showSnackBar('Нет нот для воспроизведения',
                                    Colors.orange);
                                return;
                              }
                              _controller.togglePlayback();
                            },
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Icon(Icons.play_arrow),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => _saveProject(),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
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
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollUpdateNotification) {
                                    if (_controller.horizontalScrollController
                                        .hasClients) {
                                      _controller.horizontalScrollController
                                          .jumpTo(notification.metrics.pixels);
                                    }
                                  }
                                  return true;
                                },
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: AppConstants.maxBars,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      width: AppConstants.barWidth,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Colors.amber,
                                            width: 2.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
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
                            border: Border.all(
                              color: const Color.fromARGB(0, 33, 33, 33),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Scrollbar(
                            controller: _controller.verticalScrollController,
                            child: ListView.builder(
                              controller: _controller.verticalScrollController,
                              padding: const EdgeInsets.all(0),
                              itemCount: _controller.tracks.length,
                              itemBuilder: (context, index) {
                                final track = _controller.tracks[index];
                                final trackSegment = _selectedTrackId == track.id 
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
                                          track.id, instrument);
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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