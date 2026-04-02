import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/voice_recorder_service.dart';

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
  late VoiceRecorderService _voiceRecorder;
  bool _isPlaying = false;
  bool _isRecordingVoice = false;
  
  // Выбор длительности ноты (больше не используется, но оставляем для совместимости)
  int _selectedNoteDuration = 4;
  
  // Контроллеры
  late ScrollController _timeScaleController;
  late ScrollController _notesGridController;
  late ScrollController _verticalScrollController;

  static const int minNote = 48;
  static const int maxNote = 84;

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;

  @override
  void initState() {
    super.initState();
    currentTrack = widget.track;
    
    maxTicks = AppConstants.maxTicks;
    ticksPerBeat = AppConstants.ticksPerBeat;
    beatsPerBar = AppConstants.beatsPerBar;
    
    _timeScaleController = ScrollController();
    _notesGridController = ScrollController();
    _verticalScrollController = ScrollController();
    
    // Инициализируем сервис записи голоса
    _voiceRecorder = VoiceRecorderService();
    _voiceRecorder.initialize();
    _voiceRecorder.onNotesDetected = _onVoiceNotesDetected;
    
    // Устанавливаем инструмент дорожки
    _setupTrackInstrument();
  }
  
  void _setupTrackInstrument() {
    _audioService.setTrackInstrument(currentTrack.id, currentTrack.instrument);
    debugPrint('🎹 Установлен инструмент для дорожки "${currentTrack.name}": ${currentTrack.instrument}');
  }

  @override
  void dispose() {
    _timeScaleController.dispose();
    _notesGridController.dispose();
    _verticalScrollController.dispose();
    
    _audioService.stopPlayback();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      // Останавливаем запись
      final notes = await _voiceRecorder.stopRecording();
      setState(() {
        _isRecordingVoice = false;
      });
      
      if (notes.isNotEmpty) {
        _showSnackBar('🎤 Распознано ${notes.length} нот', Colors.green);
      } else {
        _showSnackBar('🎤 Ноты не распознаны', Colors.orange);
      }
    } else {
      // Начинаем запись
      try {
        await _voiceRecorder.startRecording();
        setState(() {
          _isRecordingVoice = true;
        });
        _showSnackBar('🎤 Напевайте мелодию...', Colors.blue);
      } catch (e) {
        _showSnackBar('❌ Ошибка: нет доступа к микрофону', Colors.red);
      }
    }
  }
  
  void _onVoiceNotesDetected(List<VoiceNote> notes) {
    setState(() {
      // Добавляем распознанные ноты в текущую дорожку
      for (var voiceNote in notes) {
        // Проверяем диапазон
        if (voiceNote.pitch >= minNote && voiceNote.pitch <= maxNote) {
          // Проверяем, нет ли уже такой ноты на этом месте
          bool exists = currentTrack.notes.any((note) =>
              note.pitch == voiceNote.pitch &&
              note.startTick == voiceNote.startTick);
          
          if (!exists) {
            currentTrack.notes.add(
              MidiNote(
                pitch: voiceNote.pitch,
                startTick: voiceNote.startTick,
                durationTicks: voiceNote.durationTicks,
              ),
            );
          }
        }
      }
      
      // Сортируем ноты
      currentTrack.notes.sort((a, b) {
        if (a.startTick != b.startTick) return a.startTick.compareTo(b.startTick);
        return a.pitch.compareTo(b.pitch);
      });
      
      // Обновляем дорожку
      widget.onTrackUpdated(currentTrack);
    });
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

      _audioService.setTrackInstrument(currentTrack.id, currentTrack.instrument);
      
      _audioService.startPlayback(
        [currentTrack], 
        onTick: () {},
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollLeft() {
    if (_timeScaleController.hasClients && _notesGridController.hasClients) {
      final newOffset = _timeScaleController.offset - AppConstants.barWidth;
      final clampedOffset = newOffset.clamp(
        0.0, 
        _timeScaleController.position.maxScrollExtent
      );
      
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
      final clampedOffset = newOffset.clamp(
        0.0, 
        _timeScaleController.position.maxScrollExtent
      );
      
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

  String _getOctaveName(int midiNote) {
    if (midiNote % 12 == 0) {
      final octave = (midiNote ~/ 12) - 1;
      return 'C$octave';
    }
    return '';
  }

  bool _isBlackKey(int midiNote) {
    final noteInOctave = midiNote % 12;
    return noteInOctave == 1 || noteInOctave == 3 || 
           noteInOctave == 6 || noteInOctave == 8 || noteInOctave == 10;
  }

  bool _isNotePresent(int midiNote, int tick) {
    return currentTrack.notes.any(
      (note) => note.pitch == midiNote &&
                tick >= note.startTick &&
                tick < note.startTick + note.durationTicks,
    );
  }

  void _addOrRemoveNote(int midiNote, int tick) {
    if (_isPlaying) return;
    
    setState(() {
      final existingNoteIndex = currentTrack.notes.indexWhere(
        (note) => note.pitch == midiNote &&
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
            durationTicks: _selectedNoteDuration,
          ),
        );
        debugPrint('➕ Добавлена нота: $midiNote на тике $tick, длительность: $_selectedNoteDuration');
        
        // Играем ноту для предпросмотра с инструментом дорожки
        _audioService.playNoteForTrack(currentTrack.id, midiNote);
        
        // Останавливаем через длительность ноты
        Future.delayed(Duration(milliseconds: _selectedNoteDuration * AppConstants.millisecondsPerTick), () {
          _audioService.stopNoteForTrack(currentTrack.id, midiNote);
        });
      }

      currentTrack.notes.sort((a, b) {
        if (a.startTick != b.startTick) return a.startTick.compareTo(b.startTick);
        return a.pitch.compareTo(b.pitch);
      });
      
      widget.onTrackUpdated(currentTrack);
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
    if (tickIndex % ticksPerBeat == 0) return Colors.amber.withValues(alpha: 0.7);
    if (tickIndex % 4 == 0) return Colors.amber.withValues(alpha: 0.4);
    return Colors.grey.shade700;
  }

  Widget _buildMicrophoneButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isRecordingVoice 
            ? Colors.red.withValues(alpha: 0.8)
            : currentTrack.color.withValues(alpha: 0.4),
      ),
      child: IconButton(
        icon: Icon(
          _isRecordingVoice ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 20,
        ),
        onPressed: _toggleVoiceRecording,
        tooltip: _isRecordingVoice ? 'Остановить запись' : 'Записать голос',
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildClearButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentTrack.color.withValues(alpha: 0.4),
      ),
      child: IconButton(
        icon: const Icon(Icons.delete, color: Colors.white, size: 20),
        onPressed: _clearAllNotes,
        tooltip: 'Очистить все ноты',
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildPlayButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentTrack.color.withValues(alpha: 0.4),
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

  // Новая кнопка микрофона в виде большой круглой кнопки
  // Большая кнопка микрофона
Widget _buildBigMicrophoneButton() {
  return Center(
    child: GestureDetector(
      onTap: _toggleVoiceRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecordingVoice ? Colors.red : Colors.white, // Белая до записи, красная во время
          boxShadow: [
            BoxShadow(
              color: (_isRecordingVoice ? Colors.red : Colors.white).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          _isRecordingVoice ? Icons.mic : Icons.mic_none,
          color: _isRecordingVoice ? Colors.white : currentTrack.color, // Иконка: белая на красном, цветная на белом
          size: 40,
        ),
      ),
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
          // Убираем микрофон из AppBar
          _buildClearButton(),
          const SizedBox(width: 8),
          _buildPlayButton(),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppConstants.horizontalPadding),
        child: Column(
          children: [
            const SizedBox(height: 12),
            
            // Временная шкала со стрелочками
            Row(
              children: [
                Container(
                  width: AppConstants.keyAreaWidth - 7,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: currentTrack.color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _scrollLeft,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: currentTrack.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.chevron_left, color: currentTrack.color, size: 24),
                        ),
                      ),
                      GestureDetector(
                        onTap: _scrollRight,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: currentTrack.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.chevron_right, color: currentTrack.color, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
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
                                    style: const TextStyle(color: Colors.amber, fontSize: 10),
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
                            Container(
                              width: AppConstants.keyAreaWidth,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade800),
                                  right: BorderSide(color: Colors.grey.shade700),
                                ),
                                color: isBlackKey ? Colors.grey[900] : Colors.grey[850],
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
                            
                            Container(
                              width: 2,
                              height: 30,
                              color: Colors.amber,
                            ),
                            
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                controller: _notesGridController,
                                itemCount: maxTicks,
                                itemBuilder: (context, tickIndex) {
                                  final isNotePresent = _isNotePresent(midiNote, tickIndex);

                                  return GestureDetector(
                                    onTap: () => _addOrRemoveNote(midiNote, tickIndex),
                                    child: Container(
                                      width: AppConstants.noteCellWidth,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: _getLineColor(tickIndex + 1),
                                            width: _getLineWidth(tickIndex + 1),
                                          ),
                                          bottom: BorderSide(color: Colors.grey.shade800),
                                        ),
                                        color: isNotePresent
                                            ? currentTrack.color.withValues(alpha: 0.7)
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
            
            // Большая кнопка микрофона вместо панели длительности нот
            const SizedBox(height: 12),
            _buildBigMicrophoneButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}