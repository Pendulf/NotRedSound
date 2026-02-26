import 'dart:async';
import 'dart:io';
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
  
  final Set<int> _activeNotes = {};
  final Map<String, Timer> _noteTimers = {};

  // Карта для хранения инструментов дорожек
final Map<String, int> _trackInstruments = {};

// Установка инструмента для конкретной дорожки
void setTrackInstrument(String trackId, String instrumentName) {
  final program = instruments[instrumentName];
  if (program != null) {
    _trackInstruments[trackId] = program;
  }
}
  
  int _maxTick = 0;
  int _currentChannel = 0; // 0 для обычных инструментов, 9 для ударных
  
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
      }
    } catch (e) {
    }
  }

  void setInstrument(String instrumentName) {
    if (!_isInitialized) return;
    
    final program = instruments[instrumentName];
    if (program != null) {
      if (program == 128) {
        // Ударные - используем канал 9
        _currentChannel = 9;
      } else {
        // Обычный инструмент - Program Change на канале 0
        _currentChannel = 0;
        _midiEngine?.changeProgram(program: program);
      }
    }
  }

  // ПУБЛИЧНЫЙ МЕТОД для воспроизведения ноты (предпросмотр)
  Future<void> playNote(int pitch) async {
    if (!_isInitialized) return;
    try {
      if (_currentChannel == 9) {
        // На канале 9 pitch определяет ударный инструмент
      }
      await _midiEngine?.playNote(
        note: pitch, 
        velocity: 80,
        channel: _currentChannel,
      );
    } catch (e) {
    }
  }

  // ПУБЛИЧНЫЙ МЕТОД для остановки ноты
  Future<void> stopNote(int pitch) async {
    if (!_isInitialized) return;
    try {
      await _midiEngine?.stopNote(
        note: pitch,
        channel: _currentChannel,
      );
    } catch (e) {
    }
  }

  void startPlayback(List<Track> tracks, {VoidCallback? onTick, VoidCallback? onFinished}) {
    if (!_isInitialized) {
      return;
    }
    
    stopPlayback();
    
    _tracks = tracks.where((t) => !t.isMuted).toList();
    if (_tracks.isEmpty) return;
    
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
    // Получаем инструмент для этой дорожки
    final program = _trackInstruments[track.id] ?? 0;
    final isDrums = program == 128;
    
    // Если это не ударные, устанавливаем программу перед воспроизведением
    if (!isDrums && _midiEngine != null) {
      _midiEngine?.changeProgram(program: program);
    }
    
    for (var note in track.notes) {
      if (note.startTick == tick && !_activeNotes.contains(note.pitch)) {
        _playNote(note.pitch, isDrums: isDrums);
        _activeNotes.add(note.pitch);
        
        final noteKey = '${track.id}_${note.pitch}';
        
        if (_noteTimers.containsKey(noteKey)) {
          _noteTimers[noteKey]?.cancel();
        }
        
        final durationMs = note.durationTicks * AppConstants.millisecondsPerTick;
        if (durationMs > 0) {
          final timer = Timer(Duration(milliseconds: durationMs), () {
            if (_isPlaying) {
              _stopNote(note.pitch);
              _activeNotes.remove(note.pitch);
              _noteTimers.remove(noteKey);
            }
          });
          _noteTimers[noteKey] = timer;
        }
      }
    }
  }
}

  Future<void> _playNote(int pitch, {bool isDrums = false}) async {
    try {
      final channel = isDrums ? 9 : 0;
      await _midiEngine?.playNote(
        note: pitch, 
        velocity: 80,
        channel: channel,
      );
      if (isDrums) {
      }
    } catch (e) {
    }
  }

  Future<void> _stopNote(int pitch) async {
    try {
      // Останавливаем на обоих каналах для надежности
      await _midiEngine?.stopNote(note: pitch, channel: 0);
      await _midiEngine?.stopNote(note: pitch, channel: 9);
    } catch (e) {
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