import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';

class PianoRollScreen extends StatefulWidget {
  final Track track;
  final Function(Track) onTrackUpdated;
  final int bpm;

  const PianoRollScreen({
    super.key,
    required this.track,
    required this.onTrackUpdated,
    this.bpm = 120,
  });

  @override
  State<PianoRollScreen> createState() => _PianoRollScreenState();
}

class _PianoRollScreenState extends State<PianoRollScreen> {
  late Track currentTrack;
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  String _currentInstrument = 'Piano';

  // Два отдельных контроллера
  late ScrollController _timeScaleController;
  late ScrollController _notesGridController;
  late ScrollController _verticalScrollController;

  static const int minNote = 48;
  static const int maxNote = 84;

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;

  final List<String> _instruments = [
    'Пианино',
    'Электро пианино',
    'Орган',
    'Гитара',
    'Бас',
    'Арфа',
    'Синт',
    'Барабаны',
  ];

  @override
  void initState() {
    super.initState();
    currentTrack = widget.track;
    _currentInstrument = currentTrack.instrument;

    maxTicks = AppConstants.maxTicks;
    ticksPerBeat = AppConstants.ticksPerBeat;
    beatsPerBar = AppConstants.beatsPerBar;

    _timeScaleController = ScrollController();
    _notesGridController = ScrollController();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _timeScaleController.dispose();
    _notesGridController.dispose();
    _verticalScrollController.dispose();

    _audioService.stopPlayback();
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _audioService.stopPlayback();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (currentTrack.notes.isEmpty) {
        _showSnackBar('Нет нот для воспроизведения', Colors.orange);
        return;
      }

      _audioService.startPlayback(
        [currentTrack],
        onTick: () {
          // Просто играем музыку
        },
        onFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        },
      );

      setState(() {
        _isPlaying = true;
      });
    }
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
    if (_timeScaleController.hasClients && _notesGridController.hasClients) {
      final newOffset = _timeScaleController.offset - AppConstants.barWidth;
      final clampedOffset =
          newOffset.clamp(0.0, _timeScaleController.position.maxScrollExtent);

      _timeScaleController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );

      _notesGridController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_timeScaleController.hasClients && _notesGridController.hasClients) {
      final newOffset = _timeScaleController.offset + AppConstants.barWidth;
      final clampedOffset =
          newOffset.clamp(0.0, _timeScaleController.position.maxScrollExtent);

      _timeScaleController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );

      _notesGridController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  // Очистка всех нот
  void _clearAllNotes() {
    if (_isPlaying) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Очистить все ноты',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить все ноты в этой дорожке?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                currentTrack.notes.clear();
              });
              Navigator.pop(context);
              _showSnackBar('Все ноты удалены', Colors.green);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  void _showInstrumentPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Выберите инструмент',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _instruments.length,
            itemBuilder: (context, index) {
              final instrument = _instruments[index];
              final isSelected = instrument == _currentInstrument;

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: isSelected
                      ? currentTrack.color.withValues(alpha: 0.3)
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentInstrument = instrument;
                        currentTrack.instrument =
                            instrument; // Сохраняем в дорожку
                      });
                      _audioService.setInstrument(instrument);

                      // Обновляем дорожку в репозитории
                      widget.onTrackUpdated(currentTrack);

                      Navigator.pop(context);
                      _showSnackBar('Инструмент: $instrument', Colors.green);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          if (isSelected)
                            Icon(Icons.check,
                                color: currentTrack.color, size: 20),
                          if (isSelected) const SizedBox(width: 8),
                          Text(
                            instrument,
                            style: TextStyle(
                              color: isSelected
                                  ? currentTrack.color
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _getOctaveName(int midiNote) {
    if (midiNote % 12 == 0) {
      final octave = (midiNote ~/ 12) - 1;
      return 'C$octave';
    }
    return '';
  }

  bool _isBlackKey(int midiNote) {
    final noteInOctave = midiNote % 12;
    return noteInOctave == 1 ||
        noteInOctave == 3 ||
        noteInOctave == 6 ||
        noteInOctave == 8 ||
        noteInOctave == 10;
  }

  bool _isNotePresent(int midiNote, int tick) {
    return currentTrack.notes.any(
      (note) =>
          note.pitch == midiNote &&
          tick >= note.startTick &&
          tick < note.startTick + note.durationTicks,
    );
  }

  void _addOrRemoveNote(int midiNote, int tick) {
    if (_isPlaying) return;

    setState(() {
      final existingNoteIndex = currentTrack.notes.indexWhere(
        (note) =>
            note.pitch == midiNote &&
            tick >= note.startTick &&
            tick < note.startTick + note.durationTicks,
      );

      if (existingNoteIndex != -1) {
        currentTrack.notes.removeAt(existingNoteIndex);
        debugPrint('🗑️ Удалена нота: $midiNote на тике $tick');
      } else {
        currentTrack.notes.add(
          MidiNote(
            pitch: midiNote,
            startTick: tick,
            durationTicks: 4,
          ),
        );
        debugPrint('➕ Добавлена нота: $midiNote на тике $tick');

        // Играем ноту для предпросмотра
        _audioService.playNote(midiNote);
        // Останавливаем через 200 мс
        Future.delayed(const Duration(milliseconds: 200), () {
          _audioService.stopNote(midiNote);
        });
      }

      currentTrack.notes.sort((a, b) {
        if (a.startTick != b.startTick)
          return a.startTick.compareTo(b.startTick);
        return a.pitch.compareTo(b.pitch);
      });
    });
  }

  double _getLineWidth(int tickIndex) {
    if (tickIndex == 0) return 3.0;
    if (tickIndex % (ticksPerBeat * beatsPerBar) == 0) return 3.0;
    if (tickIndex % ticksPerBeat == 0) return 2.0;
    if (tickIndex % 4 == 0) return 1.5;
    return 1.0;
  }

  Color _getLineColor(int tickIndex) {
    if (tickIndex % (ticksPerBeat * beatsPerBar) == 0) return Colors.amber;
    if (tickIndex % ticksPerBeat == 0)
      return Colors.amber.withValues(alpha: 0.7);
    if (tickIndex % 4 == 0) return Colors.amber.withValues(alpha: 0.4);
    return Colors.grey.shade700;
  }

  // Кнопка выбора инструмента в круге
  Widget _buildInstrumentButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentTrack.color
            .withValues(alpha: 0.4), // Чуть темнее цвет дорожки
      ),
      child: IconButton(
        icon: Icon(
          Icons.menu,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _showInstrumentPicker,
        tooltip: 'Выбрать инструмент',
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  // Кнопка очистки в круге
  Widget _buildClearButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentTrack.color
            .withValues(alpha: 0.4), // Чуть темнее цвет дорожки
      ),
      child: IconButton(
        icon: Icon(
          Icons.delete,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _clearAllNotes,
        tooltip: 'Очистить все ноты',
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  // Кнопка Play/Stop в круге
  Widget _buildPlayButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentTrack.color
            .withValues(alpha: 0.4), // Чуть темнее цвет дорожки
      ),
      child: IconButton(
        icon: Icon(
          _isPlaying ? Icons.stop : Icons.play_arrow,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _togglePlayback,
        tooltip: _isPlaying ? 'Стоп' : 'Воспроизвести',
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          currentTrack.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: currentTrack.color.withValues(alpha: 0.8),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Кнопка выбора инструмента в круге
          _buildInstrumentButton(),

          const SizedBox(width: 8),
          // Кнопка очистки в круге
          _buildClearButton(),

          // Кнопка Play/Stop в круге
          const SizedBox(width: 8),
          _buildPlayButton(),

          // Отступ справа после последней кнопки
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: AppConstants.horizontalPadding),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Временная шкала со стрелочками
            Row(
              children: [
                // Контейнер со стрелочками
                Container(
                  width: AppConstants.keyAreaWidth - 7,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: currentTrack.color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Стрелка влево
                      GestureDetector(
                        onTap: _scrollLeft,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: currentTrack.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            color: currentTrack.color,
                            size: 24,
                          ),
                        ),
                      ),

                      // Стрелка вправо
                      GestureDetector(
                        onTap: _scrollRight,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: currentTrack.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            color: currentTrack.color,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Временная шкала
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      controller: _timeScaleController,
                      itemCount: maxTicks,
                      itemBuilder: (context, index) {
                        return Container(
                          width: AppConstants.noteCellWidth,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: _getLineColor(index + 1),
                                width: _getLineWidth(index + 1),
                              ),
                            ),
                          ),
                          child: index % ticksPerBeat == 0
                              ? Center(
                                  child: Text(
                                    '${index ~/ ticksPerBeat + 1}',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Piano Roll сетка
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _verticalScrollController,
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    itemCount: maxNote - minNote + 1,
                    itemBuilder: (context, noteIndex) {
                      final midiNote = maxNote - noteIndex;
                      final isBlackKey = _isBlackKey(midiNote);
                      final octaveName = _getOctaveName(midiNote);

                      return Container(
                        height: 30,
                        child: Row(
                          children: [
                            // Клавиши слева
                            Container(
                              width: AppConstants.keyAreaWidth,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: Colors.grey.shade800),
                                  right:
                                      BorderSide(color: Colors.grey.shade700),
                                ),
                                color: isBlackKey
                                    ? Colors.grey[900]
                                    : Colors.grey[850],
                              ),
                              child: Center(
                                child: octaveName.isNotEmpty
                                    ? Text(
                                        octaveName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: currentTrack.color,
                                          fontSize: 14,
                                        ),
                                      )
                                    : null,
                              ),
                            ),

                            // Разделитель
                            Container(
                              width: 2,
                              height: 30,
                              color: Colors.amber,
                            ),

                            // Сетка нот
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                controller: _notesGridController,
                                itemCount: maxTicks,
                                itemBuilder: (context, tickIndex) {
                                  final isNotePresent =
                                      _isNotePresent(midiNote, tickIndex);

                                  return GestureDetector(
                                    onTap: () =>
                                        _addOrRemoveNote(midiNote, tickIndex),
                                    child: Container(
                                      width: AppConstants.noteCellWidth,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: _getLineColor(tickIndex + 1),
                                            width: _getLineWidth(tickIndex + 1),
                                          ),
                                          bottom: BorderSide(
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        color: isNotePresent
                                            ? currentTrack.color
                                                .withValues(alpha: 0.7)
                                            : Colors.transparent,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

          ],
        ),
      ),
    );
  }
}
