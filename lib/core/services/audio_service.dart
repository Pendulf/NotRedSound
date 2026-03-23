import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_engine/flutter_midi_engine.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/track_model.dart';
import '../constants/app_constants.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterMidiEngine? _midiEngine;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  int _currentTick = 0;
  List<Track> _tracks = [];
  VoidCallback? _onTickCallback;
  VoidCallback? _onPlaybackFinishedCallback;
  bool _isInitialized = false;
  
  // Храним активные ноты с информацией о канале
  final Set<String> _activeNotes = {}; // Формат: "${channel}_${pitch}"
  final Map<String, Timer> _noteTimers = {};
  
  // Карта для хранения MIDI каналов для каждой дорожки
  final Map<String, int> _trackChannels = {};
  
  // Карта для хранения инструментов дорожек (MIDI program)
  final Map<String, int> _trackInstruments = {};
  
  // Следующий доступный канал (0-15, но 9 зарезервирован для ударных)
  int _nextChannel = 0;
  
  static const int DRUMS_CHANNEL = 9;
  
  // Доступные MIDI каналы (исключая канал 9 для ударных)
  final List<int> _availableChannels = [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15];
  
  int _maxTick = 0;
  
  static const Map<String, int> instruments = {
    'Пианино': 0,
    'Электро пианино': 4,
    'Орган': 16,
    'Гитара': 24,
    'Бас': 32,
    'Арфа': 48,
    'Синт': 80,
    'Барабаны': 128,  // Специальное значение для ударных
  };

  bool get isPlaying => _isPlaying;
  int get currentTick => _currentTick;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      _midiEngine = FlutterMidiEngine();
      
      await _midiEngine?.unmute();
      
      final tempDir = await getTemporaryDirectory();
      final sf2Path = '${tempDir.path}/FluidR3_GM.sf2';
      
      final sf2File = File(sf2Path);
      if (!await sf2File.exists()) {
        try {
          final byteData = await rootBundle.load('assets/sounds/FluidR3_GM.sf2');
          final buffer = byteData.buffer;
          await sf2File.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
          );
        } catch (e) {
          return;
        }
      }
      
      final success = await _midiEngine?.loadSoundfont(sf2Path);
      
      if (success == true) {
        _isInitialized = true;
        await _midiEngine?.setVolume(volume: 100);
        
        // Инициализируем все каналы с программой по умолчанию (пианино)
        for (int channel in _availableChannels) {
          await _midiEngine?.changeProgram(program: 0, channel: channel);
        }
        // Инициализируем канал ударных
        await _midiEngine?.changeProgram(program: 0, channel: DRUMS_CHANNEL);
      }
    } catch (e) {
    }
  }

  // Назначение канала для дорожки
  int _assignChannelForTrack(String trackId, bool isDrums) {
    if (_trackChannels.containsKey(trackId)) {
      return _trackChannels[trackId]!;
    }
    
    int channel;
    if (isDrums) {
      channel = DRUMS_CHANNEL;
    } else {
      if (_nextChannel >= _availableChannels.length) {
        _nextChannel = 0; // Если каналы закончились, начинаем сначала
      }
      channel = _availableChannels[_nextChannel];
      _nextChannel++;
    }
    
    _trackChannels[trackId] = channel;
    debugPrint('🎵 Дорожке $trackId назначен канал $channel');
    return channel;
  }

  // Установка инструмента для конкретной дорожки
  void setTrackInstrument(String trackId, String instrumentName) async {
    if (!_isInitialized) return;
    
    final program = instruments[instrumentName];
    if (program != null) {
      _trackInstruments[trackId] = program;
      
      final isDrums = program == 128;
      final channel = _assignChannelForTrack(trackId, isDrums);
      
      // Устанавливаем программу на канале дорожки
      if (isDrums) {
        // Для ударных не нужно менять программу, они всегда на канале 9
        debugPrint('🥁 Установлены ударные для дорожки $trackId на канале $channel');
      } else {
        await _midiEngine?.changeProgram(program: program, channel: channel);
        debugPrint('🎹 Установлен инструмент $instrumentName (program $program) для дорожки $trackId на канале $channel');
      }
    }
  }

  // Предпросмотр ноты с инструментом из конкретной дорожки
  Future<void> playNoteForTrack(String trackId, int pitch) async {
    if (!_isInitialized) return;
    
    final program = _trackInstruments[trackId];
    if (program == null) return;
    
    final isDrums = program == 128;
    final channel = _assignChannelForTrack(trackId, isDrums);
    
    try {
      // Для обычных инструментов убеждаемся, что программа установлена
      if (!isDrums) {
        await _midiEngine?.changeProgram(program: program, channel: channel);
      }
      
      await _midiEngine?.playNote(
        note: pitch, 
        velocity: 80,
        channel: channel,
      );
      
      debugPrint('🎵 Воспроизведение ноты $pitch на канале $channel для дорожки $trackId');
    } catch (e) {
      debugPrint('❌ Ошибка воспроизведения ноты: $e');
    }
  }
  
  // Остановка ноты для конкретной дорожки
  Future<void> stopNoteForTrack(String trackId, int pitch) async {
    if (!_isInitialized) return;
    
    final program = _trackInstruments[trackId];
    if (program == null) return;
    
    final isDrums = program == 128;
    final channel = _assignChannelForTrack(trackId, isDrums);
    
    try {
      await _midiEngine?.stopNote(
        note: pitch,
        channel: channel,
      );
    } catch (e) {
      debugPrint('❌ Ошибка остановки ноты: $e');
    }
  }

  // Старый метод playNote оставляем для обратной совместимости
  Future<void> playNote(int pitch) async {
    if (!_isInitialized) return;
    // По умолчанию используем канал 0
    await _midiEngine?.playNote(note: pitch, velocity: 80, channel: 0);
  }

  // Старый метод stopNote оставляем для обратной совместимости
  Future<void> stopNote(int pitch) async {
    if (!_isInitialized) return;
    await _midiEngine?.stopNote(note: pitch, channel: 0);
  }

  void startPlayback(List<Track> tracks, {VoidCallback? onTick, VoidCallback? onFinished}) {
    if (!_isInitialized) {
      return;
    }
    
    stopPlayback();
    
    _tracks = tracks.where((t) => !t.isMuted).toList();
    if (_tracks.isEmpty) return;
    
    // Для каждой дорожки заранее назначаем каналы и устанавливаем инструменты
    for (var track in _tracks) {
      final program = _trackInstruments[track.id] ?? 0;
      final isDrums = program == 128;
      final channel = _assignChannelForTrack(track.id, isDrums);
      
      if (!isDrums) {
        // Асинхронно устанавливаем программу, но не ждем
        _midiEngine?.changeProgram(program: program, channel: channel);
      }
    }
    
    _maxTick = _tracks.expand((t) => t.notes).fold(0, (max, note) {
      return note.startTick + note.durationTicks > max 
          ? note.startTick + note.durationTicks 
          : max;
    });
    
    if (_maxTick == 0) return;
    
    _isPlaying = true;
    _onTickCallback = onTick;
    _onPlaybackFinishedCallback = onFinished;
    _currentTick = 0;
    _activeNotes.clear();
    
    final tickDurationMs = AppConstants.millisecondsPerTick;
    
    _playbackTimer = Timer.periodic(Duration(milliseconds: tickDurationMs), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      
      try {
        _playNotesAtTick(_currentTick);
        _currentTick++;
        
        if (_currentTick > _maxTick) {
          _currentTick = 0;
          _stopAllNotes();
          _isPlaying = false;
          _playbackTimer?.cancel();
          _playbackTimer = null;
          
          _onPlaybackFinishedCallback?.call();
        } else {
          if (_currentTick % 8 == 0) {
            _onTickCallback?.call();
          }
        }
      } catch (e) {
      }
    });
  }

  void _playNotesAtTick(int tick) {
    for (var track in _tracks) {
      final program = _trackInstruments[track.id] ?? 0;
      final isDrums = program == 128;
      final channel = _trackChannels[track.id] ?? (isDrums ? DRUMS_CHANNEL : 0);
      
      for (var note in track.notes) {
        if (note.startTick == tick) {
          final noteKey = '${channel}_${note.pitch}';
          
          if (!_activeNotes.contains(noteKey)) {
            _playNoteOnChannel(note.pitch, channel, isDrums);
            _activeNotes.add(noteKey);
            
            if (_noteTimers.containsKey(noteKey)) {
              _noteTimers[noteKey]?.cancel();
            }
            
            final durationMs = note.durationTicks * AppConstants.millisecondsPerTick;
            if (durationMs > 0) {
              final timer = Timer(Duration(milliseconds: durationMs), () {
                if (_isPlaying) {
                  _stopNoteOnChannel(note.pitch, channel);
                  _activeNotes.remove(noteKey);
                  _noteTimers.remove(noteKey);
                }
              });
              _noteTimers[noteKey] = timer;
            }
          }
        }
      }
    }
  }

  Future<void> _playNoteOnChannel(int pitch, int channel, bool isDrums) async {
    try {
      await _midiEngine?.playNote(
        note: pitch, 
        velocity: 80,
        channel: channel,
      );
      if (isDrums) {
        debugPrint('🥁 Воспроизведение ударной ноты $pitch на канале $channel');
      }
    } catch (e) {
      debugPrint('❌ Ошибка воспроизведения ноты на канале $channel: $e');
    }
  }

  Future<void> _stopNoteOnChannel(int pitch, int channel) async {
    try {
      await _midiEngine?.stopNote(
        note: pitch,
        channel: channel,
      );
    } catch (e) {
      debugPrint('❌ Ошибка остановки ноты на канале $channel: $e');
    }
  }

  Future<void> _stopAllNotes() async {
    await _midiEngine?.stopAllNotes();
    _activeNotes.clear();
    for (var timer in _noteTimers.values) {
      timer.cancel();
    }
    _noteTimers.clear();
  }

  void stopPlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _stopAllNotes();
  }

  void dispose() {
    stopPlayback();
    _midiEngine?.stopAllNotes();
    _midiEngine?.unloadSoundfont();
    _midiEngine = null;
  }
}