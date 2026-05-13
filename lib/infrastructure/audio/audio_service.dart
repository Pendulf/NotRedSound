import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_engine/flutter_midi_engine.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/track_model.dart';
import '../../core/constants/app_constants.dart';

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
  Future<bool>? _initializingFuture;

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  StreamSubscription<dynamic>? _becomingNoisySubscription;
  StreamSubscription<dynamic>? _interruptionSubscription;
  Timer? _audioRecoverDebounceTimer;

  bool _isPlaying = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isRecoveringAudioEngine = false;

  int _currentTick = 0;
  int _maxTick = 0;
  int _playbackGeneration = 0;

  VoidCallback? _onTickCallback;
  VoidCallback? _onPlaybackFinishedCallback;

  final Map<int, List<_ScheduledNoteEvent>> _noteOnEvents = {};
  final Map<int, List<_ScheduledNoteEvent>> _noteOffEvents = {};

  final Map<String, int> _trackChannels = {};
  final Map<String, int> _trackInstruments = {};

  int _nextChannel = 0;

  static const int _drumsChannel = 9;

  static const List<int> _availableMelodicChannels = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    10,
    11,
    12,
    13,
    14,
    15,
  ];

  static const Map<String, int> instruments = {
    'Пианино': 0,
    'Яркое пианино': 1,
    'Электропианино': 4,
    'Челеста': 8,
    'Музыкальная шкатулка': 10,
    'Маримба': 12,
    'Ситар': 15,
    'Кристалл': 98,
    'Орган': 16,
    'Перкуссионный орган': 17,
    'Рок-орган': 18,
    'Церковный орган': 19,
    'Губная гармошка': 22,
    'Нейлоновая гитара': 24,
    'Стальная гитара': 25,
    'Джаз-гитара': 26,
    'Чистая гитара': 27,
    'Овердрайв гитара': 29,
    'Дисторшн гитара': 30,
    'Акустический бас': 32,
    'Звонкий бас': 34,
    'Синт-бас': 38,
    'Скрипка': 40,
    'Виолончель': 42,
    'Приглушённые струны': 45,
    'Струнный ансамбль': 48,
    'Терменвокс': 110,
    'Хор "Аа"': 52,
    'Хор "Оо"': 53,
    'Тромбон': 57,
    'Сопрано саксофон': 64,
    'Кларнет': 71,
    'Флейта': 73,
    'Пан-флейта': 75,
    'Свист': 78,
    'Волна Квадрат': 80,
    'Волна Пила': 86,
    'Полисинт': 90,
    'Моносинт': 114,
    'Фантазия': 88,
    'Стеклянный смычок': 92,
    'Метал': 93,
    'Бочка': 116,
    'Том': 117,
    'Бочка 2': 118,
    'Ударные': 128,
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
      'Волна Квадрат',
      'Волна Пила',
      'Полисинт',
      'Моносинт',
    ],
    '🌌 Атмосфера': [
      'Фантазия',
      'Стеклянный смычок',
      'Метал',
    ],
    '🥁 Перкуссия': [
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
    return _isDrumProgram(program) ? 0 : program.clamp(0, 127).toInt();
  }

  int _allocateMelodicChannel() {
    final channel = _availableMelodicChannels[
        _nextChannel % _availableMelodicChannels.length];
    _nextChannel++;
    return channel;
  }

  int _desiredChannelForProgram(int program) {
    return _isDrumProgram(program) ? _drumsChannel : _allocateMelodicChannel();
  }

  int _velocityFromTrack(Track track, {required bool isDrums}) {
    final baseVelocity = isDrums ? 115 : 60;
    return (baseVelocity * track.volume).round().clamp(1, 127).toInt();
  }

  Future<void> initialize() async {
    await ensureInitialized(forceReload: true);
  }

  Future<bool> ensureInitialized({bool forceReload = false}) async {
    if (_isDisposed) {
      _isDisposed = false;
    }

    if (!forceReload && _isInitialized && _midiEngine != null) {
      await _configurePlaybackSession();
      return true;
    }

    final pending = _initializingFuture;
    if (pending != null) return pending;

    _initializingFuture = _initializeInternal(forceReload: forceReload);
    return _initializingFuture!.whenComplete(() {
      _initializingFuture = null;
    });
  }

  Future<void> _configurePlaybackSession() async {
    final session = await AudioSession.instance;

    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );

    await session.setActive(true);

    _deviceChangeSubscription ??= session.devicesChangedEventStream.listen((_) {
      debugPrint('Audio device changed. Scheduling MIDI engine recovery...');
      _scheduleAudioEngineRecovery();
    });

    _becomingNoisySubscription ??= session.becomingNoisyEventStream.listen((_) {
      debugPrint(
          'Audio output became noisy. Scheduling MIDI engine recovery...');
      _scheduleAudioEngineRecovery();
    });

    _interruptionSubscription ??= session.interruptionEventStream.listen(
      (event) {
        if (event.begin) {
          stopPlayback();
        } else {
          debugPrint('Audio interruption ended. Scheduling MIDI recovery...');
          _scheduleAudioEngineRecovery();
        }
      },
    );
  }

  void _scheduleAudioEngineRecovery() {
    if (_isDisposed) return;

    _audioRecoverDebounceTimer?.cancel();
    _audioRecoverDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      () {
        unawaited(recoverAudioEngine());
      },
    );
  }

  Future<void> recoverAudioEngine() async {
    if (_isDisposed || _isRecoveringAudioEngine) return;

    _isRecoveringAudioEngine = true;
    try {
      stopPlayback();

      try {
        await _midiEngine?.stopAllNotes();
        await _midiEngine?.unloadSoundfont();
      } catch (_) {}

      _midiEngine = null;
      _isInitialized = false;
      _trackChannels.clear();
      _nextChannel = 0;

      await ensureInitialized(forceReload: true);
    } finally {
      _isRecoveringAudioEngine = false;
    }
  }

  Future<bool> _initializeInternal({required bool forceReload}) async {
    try {
      await _configurePlaybackSession();

      if (forceReload || _midiEngine == null) {
        try {
          await _midiEngine?.stopAllNotes();
          await _midiEngine?.unloadSoundfont();
        } catch (_) {}

        _midiEngine = FlutterMidiEngine();
      }

      await _midiEngine?.unmute();

      final tempDir = await getApplicationSupportDirectory();
      final sf2Path = '${tempDir.path}/Arachno_SoundFont_Version_1.0.sf2';
      final sf2File = File(sf2Path);

      if (!await sf2File.exists() || await sf2File.length() == 0) {
        final byteData = await rootBundle.load(
          'assets/sounds/Arachno_SoundFont_Version_1.0.sf2',
        );
        final buffer = byteData.buffer;
        await sf2File.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );
      }

      final success = await _midiEngine?.loadSoundfont(sf2Path);
      if (success != true) {
        _isInitialized = false;
        return false;
      }

      _isInitialized = true;
      await _safeMidiCall(() => _midiEngine?.setVolume(volume: 100));

      for (final channel in _availableMelodicChannels) {
        await _safeMidiCall(
          () => _midiEngine?.changeProgram(program: 0, channel: channel),
        );
      }

      for (final entry in _trackInstruments.entries) {
        final program = entry.value;
        if (_isDrumProgram(program)) continue;
        final channel = _channelForTrack(entry.key);
        await _safeMidiCall(
          () => _midiEngine?.changeProgram(
            program: _resolvePlaybackProgram(program),
            channel: channel,
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Audio init error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<T?> _safeMidiCall<T>(Future<T>? Function() action) async {
    if (_midiEngine == null) return null;

    try {
      return await action();
    } catch (e) {
      debugPrint('MIDI engine error: $e');
      _isInitialized = false;
      return null;
    }
  }

  Future<void> setTrackInstrument(String trackId, String instrumentName) async {
    final newProgram = instruments[instrumentName] ?? 0;
    final oldProgram = _trackInstruments[trackId];
    final oldWasDrums = oldProgram != null && _isDrumProgram(oldProgram);
    final newIsDrums = _isDrumProgram(newProgram);

    _trackInstruments[trackId] = newProgram;

    if (!await ensureInitialized()) return;

    if (_trackChannels.containsKey(trackId) && oldProgram != null) {
      if (oldWasDrums != newIsDrums) {
        final oldChannel = _trackChannels[trackId]!;
        await _safeMidiCall(() => _midiEngine?.stopAllNotes());

        if (!oldWasDrums) {
          await _safeMidiCall(
            () => _midiEngine?.changeProgram(program: 0, channel: oldChannel),
          );
        }

        _trackChannels.remove(trackId);
      }
    }

    final channel = _trackChannels.putIfAbsent(
      trackId,
      () => _desiredChannelForProgram(newProgram),
    );

    if (!newIsDrums) {
      await _safeMidiCall(
        () => _midiEngine?.changeProgram(
          program: _resolvePlaybackProgram(newProgram),
          channel: channel,
        ),
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

  Future<void> playNoteForTrack(
    String trackId,
    int pitch, {
    double volume = 1.0,
  }) async {
    if (!await ensureInitialized()) return;

    final program = _trackInstruments[trackId] ?? 0;
    final isDrums = _isDrumProgram(program);
    final channel = _channelForTrack(trackId);
    final velocity =
        ((isDrums ? 115 : 60) * volume).round().clamp(1, 127).toInt();

    if (!isDrums) {
      await _safeMidiCall(
        () => _midiEngine?.changeProgram(
          program: _resolvePlaybackProgram(program),
          channel: channel,
        ),
      );
    }

    await _safeMidiCall(
        () => _midiEngine?.stopNote(note: pitch, channel: channel));
    await _safeMidiCall(
      () => _midiEngine?.playNote(
        note: pitch,
        velocity: velocity,
        channel: channel,
      ),
    );
  }

  Future<void> stopNoteForTrack(String trackId, int pitch) async {
    if (!await ensureInitialized()) return;
    final channel = _channelForTrack(trackId);
    await _safeMidiCall(
        () => _midiEngine?.stopNote(note: pitch, channel: channel));
  }

  void startPlayback(
    List<Track> tracks, {
    int startTick = 0,
    VoidCallback? onTick,
    VoidCallback? onFinished,
  }) {
    final generation = ++_playbackGeneration;

    stopPlayback(notifyGeneration: false);

    _onTickCallback = onTick;
    _onPlaybackFinishedCallback = onFinished;
    _currentTick = startTick.clamp(0, AppConstants.maxTicks).toInt();

    final playableTracks = tracks
        .where((track) => !track.isMuted && track.notes.isNotEmpty)
        .map((track) => track.copyWith(notes: List<MidiNote>.from(track.notes)))
        .toList();

    if (playableTracks.isEmpty) return;

    _startPlaybackAsync(
      playableTracks,
      _currentTick,
      generation,
    );
  }

  Future<void> _startPlaybackAsync(
    List<Track> tracks,
    int startTick,
    int generation,
  ) async {
    if (!await ensureInitialized()) return;
    if (generation != _playbackGeneration) return;

    await _prepareEvents(tracks, startTick);
    if (generation != _playbackGeneration) return;

    if (_maxTick <= startTick) {
      _finishPlayback();
      return;
    }

    _isPlaying = true;
    _onTickCallback?.call();

    _playbackTimer = Timer.periodic(
      Duration(
          milliseconds:
              AppConstants.millisecondsPerTick.clamp(1, 1000000).toInt()),
      (timer) {
        if (!_isPlaying || generation != _playbackGeneration) {
          timer.cancel();
          return;
        }

        _processTick(_currentTick);
        _onTickCallback?.call();
        _currentTick++;

        if (_currentTick > _maxTick) {
          _finishPlayback();
        }
      },
    );
  }

  Future<void> _prepareEvents(List<Track> tracks, int startTick) async {
    _noteOnEvents.clear();
    _noteOffEvents.clear();
    _maxTick = startTick;

    for (final track in tracks) {
      final program =
          _trackInstruments[track.id] ?? instruments[track.instrument] ?? 0;
      _trackInstruments[track.id] = program;

      final isDrums = _isDrumProgram(program);
      final channel = _channelForTrack(track.id);
      final velocity = _velocityFromTrack(track, isDrums: isDrums);

      if (!isDrums) {
        await _safeMidiCall(
          () => _midiEngine?.changeProgram(
            program: _resolvePlaybackProgram(program),
            channel: channel,
          ),
        );
      }

      for (final note in track.notes) {
        if (note.durationTicks <= 0) continue;

        final noteStartTick = note.startTick;
        final noteEndTick = note.endTick;

        if (noteEndTick <= startTick) continue;

        final onTick = noteStartTick < startTick ? startTick : noteStartTick;

        _noteOnEvents.putIfAbsent(onTick, () => []).add(
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
    final offEvents = _noteOffEvents[tick] ?? const <_ScheduledNoteEvent>[];
    final onEvents = _noteOnEvents[tick] ?? const <_ScheduledNoteEvent>[];

    for (final event in offEvents) {
      _stopNoteOnChannel(event.pitch, event.channel);
    }

    for (final event in onEvents) {
      _playNoteOnChannel(event.pitch, event.channel, event.velocity);
    }
  }

  Future<void> _playNoteOnChannel(int pitch, int channel, int velocity) async {
    await _safeMidiCall(
      () => _midiEngine?.playNote(
        note: pitch,
        velocity: velocity,
        channel: channel,
      ),
    );
  }

  Future<void> _stopNoteOnChannel(int pitch, int channel) async {
    await _safeMidiCall(
        () => _midiEngine?.stopNote(note: pitch, channel: channel));
  }

  Future<void> _stopAllNotes() async {
    await _safeMidiCall(() => _midiEngine?.stopAllNotes());
  }

  void _finishPlayback() {
    if (!_isPlaying) return;
    stopPlayback();
    _onPlaybackFinishedCallback?.call();
  }

  void stopPlayback({bool notifyGeneration = true}) {
    if (notifyGeneration) {
      _playbackGeneration++;
    }

    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _noteOnEvents.clear();
    _noteOffEvents.clear();
    _stopAllNotes();
  }

  void handleAppPaused() {
    stopPlayback();
  }

  Future<void> handleAppResumed() async {
    await recoverAudioEngine();
  }

  void dispose() {
    _isDisposed = true;
    stopPlayback();

    _audioRecoverDebounceTimer?.cancel();
    _deviceChangeSubscription?.cancel();
    _becomingNoisySubscription?.cancel();
    _interruptionSubscription?.cancel();

    _audioRecoverDebounceTimer = null;
    _deviceChangeSubscription = null;
    _becomingNoisySubscription = null;
    _interruptionSubscription = null;

    _safeMidiCall(() => _midiEngine?.unloadSoundfont());
    _midiEngine = null;
    _isInitialized = false;
    _trackChannels.clear();
  }
}
