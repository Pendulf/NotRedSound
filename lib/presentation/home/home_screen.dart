import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/track_repository.dart';
import '../piano_roll/piano_roll_screen.dart';
import '../../core/constants/app_constants.dart';
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

  void _calculateBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Хотим видеть примерно 4 такта на экране
    AppConstants.barWidth = (screenWidth - 100) / 4;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                  // Настройка BPM
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

                  // Настройка количества тактов
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

                  const SizedBox(height: 16),
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
                    setState(() {}); // Обновляем UI
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

        // В методе _exportToMidi замените сообщение об успехе:

        String successMessage;
        if (_controller.tracks.length == 1 && fileName != null) {
          successMessage = share
              ? 'MIDI файл "${fileName.replaceAll('.mid', '')}" отправлен'
              : 'MIDI файл "${fileName.replaceAll('.mid', '')}" сохранен в Downloads';
        } else {
          if (share) {
            successMessage = 'ZIP архив с MIDI файлами отправлен';
          } else {
            successMessage =
                'Папка с MIDI файлами сохранена в Downloads/NotRed_Export_*';
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
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
    final startTick = barIndex * AppConstants.ticksPerBeat;
    final endTick = (barIndex + 1) * AppConstants.ticksPerBeat;

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

                // AppBar с градиентным заголовком (как кнопка настроек)
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
        _showSnackBar('Нет дорожек для воспроизведения', Colors.orange);
        return;
      }
      
      final hasNotes = _controller.tracks.any((t) => t.notes.isNotEmpty);
      if (!hasNotes) {
        _showSnackBar('Нет нот для воспроизведения', Colors.orange);
        return;
      }
      
      _controller.togglePlayback(); // Этот метод теперь просто запускает/останавливает
    },
    style: ElevatedButton.styleFrom(
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(12),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
    ),
    child: const Icon(Icons.play_arrow), // ВСЕГДА PLAY
  ),
),
                        // Кнопка сохранения MIDI
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

                        // Кнопка отправки MIDI
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

                      // Тактовая лента
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
                                  if (notification
                                      is ScrollUpdateNotification) {
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
                                      // Новый параметр
                                      _controller.renameTrack(
                                        track.id,
                                        newName,
                                      );
                                      setState(() {});
                                    },
                                    horizontalScrollController:
                                        _controller.horizontalScrollController,
                                    getNotesInBar: _getNotesInBar,
                                    getNoteRange: _getNoteRange,
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
