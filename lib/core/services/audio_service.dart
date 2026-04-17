import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_engine/flutter_midi_engine.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/track_model.dart';
import '../constants/app_constants.dart';

class _ScheduledNoteEvent {
  final int pitch;
  final int channel;
  final int velocity;

  const _ScheduledNoteEvent({
    required this.pitch,
    required this.channel,
    required this.velocity,
  });
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterMidiEngine? _midiEngine;
  Timer? _playbackTimer;

  bool _isPlaying = false;
  bool _isInitialized = false;
  int _currentTick = 0;
  int _maxTick = 0;

  List<Track> _tracks = [];
  VoidCallback? _onTickCallback;
  VoidCallback? _onPlaybackFinishedCallback;

  final Map<int, List<_ScheduledNoteEvent>> _noteOnEvents = {};
  final Map<int, List<_ScheduledNoteEvent>> _noteOffEvents = {};

  final Map<String, int> _trackChannels = {};
  final Map<String, int> _trackInstruments = {};

  int _nextChannel = 0;

  static const int _drumsChannel = 9;

  final List<int> _availableMelodicChannels = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15];

 static const Map<String, int> instruments = {
  // ===== КЛАВИШИ =====
  'Пианино': 0,
  'Яркое пианино': 1,
  'Электропианино': 4,

  // ===== КОЛОКОЛЬЧИКИ =====
  'Челеста': 8,
  'Музыкальная шкатулка': 10,
  'Маримба': 12,
  'Ситар': 15,
  'Кристалл': 98,

  // ===== ОРГАНЫ =====
  'Орган': 16,
  'Перкуссионный орган': 17,
  'Рок-орган': 18,
  'Церковный орган': 19,
  'Губная гармошка': 22,

  // ===== ГИТАРЫ =====
  'Нейлоновая гитара': 24,
  'Стальная гитара': 25,
  'Джаз-гитара': 26,
  'Чистая гитара': 27,
  'Приглушённая гитара': 28,
  'Овердрайв гитара': 29,
  'Дисторшн гитара': 30,

  // ===== БАСЫ =====
  'Акустический бас': 32,
  'Звонкий бас': 34,
  'Синт-бас': 38,

  // ===== СТРУННЫЕ =====
  'Скрипка': 40,
  'Виолончель': 42,
  'Приглушённые струны': 45,
  'Струнный ансамбль': 48,
  'Терменвокс': 110,

  // ===== ХОР =====
  'Хор "Аа"': 52,
  'Хор "Оо"': 53,

  // ===== ДУХОВЫЕ =====
  'Тромбон': 57,
  'Сопрано саксофон': 64,
  'Кларнет': 71,
  'Флейта': 73,
  'Пан-флейта': 75,
  'Свист': 78,

  // ===== СИНТЕЗАТОРЫ =====
  'Волна Квадрат': 80,
  'Волна Пила': 86,
  'Полисинт': 90,
  'Моносинт': 114,

  // ===== АТМОСФЕРА =====
  'Фантазия': 88,
  'Стеклянный смычок': 92,
  'Метал': 93,

  // ===== ПЕРКУССИЯ =====
  'Бочка': 116,
  'Том': 117,
  'Бочка 2': 118,
  'Ударные': 128,

  // ===== ЗВУКИ =====
  'Шум ладов гитары': 120,
  'Пение птиц': 123,
  'Телефон': 124,
  'Вертолёт': 125,
  'Аплодисменты': 126,
};

static const Map<String, List<String>> instrumentCategories = {

  '🎹 Клавиши': [
    'Пианино',
    'Яркое пианино',
    'Электропианино',
  ],

  '🔔 Колокольчики': [
    'Челеста',
    'Музыкальная шкатулка',
    'Маримба',
    'Ситар',
    'Кристалл',
  ],

  '🏰 Органы': [
    'Орган',
    'Перкуссионный орган',
    'Рок-орган',
    'Церковный орган',
    'Губная гармошка',
  ],

  '🎸 Гитары': [
    'Нейлоновая гитара',
    'Стальная гитара',
    'Джаз-гитара',
    'Чистая гитара',
    'Приглушённая гитара',
    'Овердрайв гитара',
    'Дисторшн гитара',
  ],

  '🎸 Басы': [
    'Акустический бас',
    'Звонкий бас',
    'Синт-бас',
  ],

  '🎻 Струнные': [
    'Скрипка',
    'Виолончель',
    'Приглушённые струны',
    'Струнный ансамбль',
    'Терменвокс',
  ],

  '🗣️ Хор': [
    'Хор "Аа"',
    'Хор "Оо"',
  ],

  '🎷 Духовые': [
    'Тромбон',
    'Сопрано саксофон',
    'Кларнет',
    'Флейта',
    'Пан-флейта',
    'Свист',
  ],

  '🎹 Синтезаторы': [
    'Квадратная волна',
    'Пила (5-я гармоника)',
    'Полисинт',
    'Моносинт',
  ],

  '🌌 Атмосфера': [
    'Фантазия',
    'Стеклянный смычок',
    'Метал',
  ],

  '🥁 Перкусия': [
    'Бочка',
    'Бочка 2',
    'Том',
    'Ударные',
  ],

  '🔊 FX звуки': [
    'Шум ладов гитары',
    'Пение птиц',
    'Телефон',
    'Вертолёт',
    'Аплодисменты',
  ],
};

  bool get isPlaying => _isPlaying;
  int get currentTick => _currentTick;
  bool get isInitialized => _isInitialized;

  bool _isDrumProgram(int program) => program == 128;

  int _resolvePlaybackProgram(int program) {
    return _isDrumProgram(program) ? 0 : program;
  }

  int _allocateMelodicChannel() {
    final channel =
        _availableMelodicChannels[_nextChannel % _availableMelodicChannels.length];
    _nextChannel++;
    return channel;
  }

  int _desiredChannelForProgram(int program) {
    return _isDrumProgram(program) ? _drumsChannel : _allocateMelodicChannel();
  }

int _velocityFromTrack(Track track, {required bool isDrums}) {
  final baseVelocity = isDrums ? 115 : 60;
  return (baseVelocity * track.volume).round().clamp(1, 127);
}

  Future<void> initialize() async {
    try {
      _midiEngine = FlutterMidiEngine();
      await _midiEngine?.unmute();

      final tempDir = await getTemporaryDirectory();
      final sf2Path = '${tempDir.path}/Arachno_SoundFont_Version_1.0.sf2';

      final sf2File = File(sf2Path);
      if (!await sf2File.exists()) {
        final byteData = await rootBundle.load('assets/sounds/Arachno_SoundFont_Version_1.0.sf2');
        final buffer = byteData.buffer;
        await sf2File.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }

      final success = await _midiEngine?.loadSoundfont(sf2Path);
      if (success == true) {
        _isInitialized = true;
        await _midiEngine?.setVolume(volume: 100);

        for (final channel in _availableMelodicChannels) {
          await _midiEngine?.changeProgram(program: 0, channel: channel);
        }
      }
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> setTrackInstrument(String trackId, String instrumentName) async {
    if (!_isInitialized) return;

    final newProgram = instruments[instrumentName] ?? 0;
    final oldProgram = _trackInstruments[trackId];
    final oldWasDrums = oldProgram != null && _isDrumProgram(oldProgram);
    final newIsDrums = _isDrumProgram(newProgram);

    _trackInstruments[trackId] = newProgram;

    if (_trackChannels.containsKey(trackId) && oldProgram != null) {
      if (oldWasDrums != newIsDrums) {
        final oldChannel = _trackChannels[trackId]!;
        try {
          await _midiEngine?.stopAllNotes();

          if (!oldWasDrums) {
            await _midiEngine?.changeProgram(program: 0, channel: oldChannel);
          }
        } catch (_) {}

        _trackChannels.remove(trackId);
      }
    }

    final channel = _trackChannels.putIfAbsent(
      trackId,
      () => _desiredChannelForProgram(newProgram),
    );

    if (!newIsDrums) {
      await _midiEngine?.changeProgram(
        program: _resolvePlaybackProgram(newProgram),
        channel: channel,
      );
    }
  }

  int _channelForTrack(String trackId) {
    final existing = _trackChannels[trackId];
    if (existing != null) return existing;

    final program = _trackInstruments[trackId] ?? 0;
    final channel = _desiredChannelForProgram(program);
    _trackChannels[trackId] = channel;
    return channel;
  }

  Future<void> playNoteForTrack(String trackId, int pitch, {double volume = 1.0}) async {
  if (!_isInitialized) return;

  final program = _trackInstruments[trackId] ?? 0;
  final isDrums = _isDrumProgram(program);
  final channel = _channelForTrack(trackId);

  final velocity = ((isDrums ? 110 : 90) * volume).round().clamp(1, 127);

  try {
    if (!isDrums) {
      await _midiEngine?.changeProgram(
        program: _resolvePlaybackProgram(program),
        channel: channel,
      );
    }

    await _midiEngine?.stopNote(note: pitch, channel: channel);
    await _midiEngine?.playNote(
      note: pitch,
      velocity: velocity,
      channel: channel,
    );
  } catch (e) {
    debugPrint('Preview play error: $e');
  }
}

  Future<void> stopNoteForTrack(String trackId, int pitch) async {
    if (!_isInitialized) return;

    final channel = _channelForTrack(trackId);

    try {
      await _midiEngine?.stopNote(note: pitch, channel: channel);
    } catch (e) {
      debugPrint('Preview stop error: $e');
    }
  }

  void startPlayback(
    List<Track> tracks, {
    int startTick = 0,
    VoidCallback? onTick,
    VoidCallback? onFinished,
  }) {
    if (!_isInitialized) return;

    stopPlayback();

    _tracks = tracks.where((t) => !t.isMuted && t.notes.isNotEmpty).toList();
    if (_tracks.isEmpty) return;

    _onTickCallback = onTick;
    _onPlaybackFinishedCallback = onFinished;
    _currentTick = startTick < 0 ? 0 : startTick;

    _prepareEvents(_tracks, _currentTick).then((_) {
      if (_maxTick <= 0) return;

      _isPlaying = true;

      _playbackTimer = Timer.periodic(
        Duration(milliseconds: AppConstants.millisecondsPerTick),
        (timer) {
          if (!_isPlaying) {
            timer.cancel();
            return;
          }

          _processTick(_currentTick);
          _onTickCallback?.call();
          _currentTick++;

          if (_currentTick > _maxTick) {
            stopPlayback();
            _onPlaybackFinishedCallback?.call();
          }
        },
      );
    });
  }

  Future<void> _prepareEvents(List<Track> tracks, int startTick) async {
    _noteOnEvents.clear();
    _noteOffEvents.clear();
    _maxTick = 0;

    for (final track in tracks) {
      final program = _trackInstruments[track.id] ?? 0;
      final isDrums = _isDrumProgram(program);
      final channel = _channelForTrack(track.id);
      final velocity = _velocityFromTrack(track, isDrums: isDrums);

      if (!isDrums) {
        await _midiEngine?.changeProgram(
          program: _resolvePlaybackProgram(program),
          channel: channel,
        );
      }

      for (final note in track.notes) {
        if (note.durationTicks <= 0) continue;

        final noteStartTick = note.startTick;
        final noteEndTick = note.endTick;

        if (noteEndTick < startTick) continue;

        _noteOnEvents.putIfAbsent(noteStartTick, () => []).add(
          _ScheduledNoteEvent(
            pitch: note.pitch,
            channel: channel,
            velocity: velocity,
          ),
        );

        _noteOffEvents.putIfAbsent(noteEndTick, () => []).add(
          _ScheduledNoteEvent(
            pitch: note.pitch,
            channel: channel,
            velocity: velocity,
          ),
        );

        if (noteEndTick > _maxTick) {
          _maxTick = noteEndTick;
        }
      }
    }
  }

  void _processTick(int tick) {
    final offEvents = _noteOffEvents[tick] ?? const [];
    final onEvents = _noteOnEvents[tick] ?? const [];

    for (final event in offEvents) {
      _stopNoteOnChannel(event.pitch, event.channel);
    }

    for (final event in onEvents) {
      _playNoteOnChannel(event.pitch, event.channel, event.velocity);
    }
  }

  Future<void> _playNoteOnChannel(int pitch, int channel, int velocity) async {
    try {
      await _midiEngine?.playNote(
        note: pitch,
        velocity: velocity,
        channel: channel,
      );
    } catch (e) {
      debugPrint('Playback play error: $e');
    }
  }

  Future<void> _stopNoteOnChannel(int pitch, int channel) async {
    try {
      await _midiEngine?.stopNote(note: pitch, channel: channel);
    } catch (e) {
      debugPrint('Playback stop error: $e');
    }
  }

  Future<void> _stopAllNotes() async {
    try {
      await _midiEngine?.stopAllNotes();
    } catch (_) {}
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