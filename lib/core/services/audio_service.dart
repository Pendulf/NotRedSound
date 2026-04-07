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
  final bool isDrums;

  const _ScheduledNoteEvent({
    required this.pitch,
    required this.channel,
    required this.isDrums,
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

  static const int drumsChannel = 9;

  final List<int> _availableChannels = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15
  ];

  static const Map<String, int> instruments = {
    'Пианино': 0,
    'Электро пианино': 4,
    'Орган': 16,
    'Гитара': 24,
    'Бас': 32,
    'Арфа': 46,
    'Синт': 80,
    'Барабаны': 128,
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
        final byteData = await rootBundle.load('assets/sounds/FluidR3_GM.sf2');
        final buffer = byteData.buffer;
        await sf2File.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        );
      }

      final success = await _midiEngine?.loadSoundfont(sf2Path);
      if (success == true) {
        _isInitialized = true;
        await _midiEngine?.setVolume(volume: 100);

        for (final channel in _availableChannels) {
          await _midiEngine?.changeProgram(program: 0, channel: channel);
        }
      }
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  int _assignChannelForTrack(String trackId, bool isDrums) {
    if (_trackChannels.containsKey(trackId)) {
      return _trackChannels[trackId]!;
    }

    final channel = isDrums
        ? drumsChannel
        : _availableChannels[_nextChannel++ % _availableChannels.length];

    _trackChannels[trackId] = channel;
    return channel;
  }

  Future<void> setTrackInstrument(String trackId, String instrumentName) async {
    if (!_isInitialized) return;

    final program = instruments[instrumentName] ?? 0;
    _trackInstruments[trackId] = program;

    final isDrums = program == 128;
    final channel = _assignChannelForTrack(trackId, isDrums);

    if (!isDrums) {
      await _midiEngine?.changeProgram(program: program, channel: channel);
    }
  }

  Future<void> playNoteForTrack(String trackId, int pitch) async {
    if (!_isInitialized) return;

    final program = _trackInstruments[trackId] ?? 0;
    final isDrums = program == 128;
    final channel = _assignChannelForTrack(trackId, isDrums);

    try {
      if (!isDrums) {
        await _midiEngine?.changeProgram(program: program, channel: channel);
      }

      // На превью всегда делаем retrigger
      await _midiEngine?.stopNote(note: pitch, channel: channel);
      await _midiEngine?.playNote(
        note: pitch,
        velocity: 90,
        channel: channel,
      );
    } catch (e) {
      debugPrint('Preview play error: $e');
    }
  }

  Future<void> stopNoteForTrack(String trackId, int pitch) async {
    if (!_isInitialized) return;

    final program = _trackInstruments[trackId] ?? 0;
    final isDrums = program == 128;
    final channel = _assignChannelForTrack(trackId, isDrums);

    try {
      await _midiEngine?.stopNote(note: pitch, channel: channel);
    } catch (e) {
      debugPrint('Preview stop error: $e');
    }
  }

  void startPlayback(
    List<Track> tracks, {
    VoidCallback? onTick,
    VoidCallback? onFinished,
  }) {
    if (!_isInitialized) return;

    stopPlayback();

    _tracks = tracks.where((t) => !t.isMuted && t.notes.isNotEmpty).toList();
    if (_tracks.isEmpty) return;

    _onTickCallback = onTick;
    _onPlaybackFinishedCallback = onFinished;
    _currentTick = 0;

    _prepareEvents(_tracks);
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
  }

  void _prepareEvents(List<Track> tracks) {
    _noteOnEvents.clear();
    _noteOffEvents.clear();
    _maxTick = 0;

    for (final track in tracks) {
      final program = _trackInstruments[track.id] ?? 0;
      final isDrums = program == 128;
      final channel = _assignChannelForTrack(track.id, isDrums);

      if (!isDrums) {
        _midiEngine?.changeProgram(program: program, channel: channel);
      }

      for (final note in track.notes) {
        if (note.durationTicks <= 0) continue;

        final startTick = note.startTick;
        final endTick = note.endTick;

        _noteOnEvents.putIfAbsent(startTick, () => []).add(
              _ScheduledNoteEvent(
                pitch: note.pitch,
                channel: channel,
                isDrums: isDrums,
              ),
            );

        _noteOffEvents.putIfAbsent(endTick, () => []).add(
              _ScheduledNoteEvent(
                pitch: note.pitch,
                channel: channel,
                isDrums: isDrums,
              ),
            );

        if (endTick > _maxTick) {
          _maxTick = endTick;
        }
      }
    }
  }

  void _processTick(int tick) {
    final offEvents = _noteOffEvents[tick] ?? const [];
    final onEvents = _noteOnEvents[tick] ?? const [];

    // Сначала всегда OFF, потом ON — это важно для retrigger одинаковых нот
    for (final event in offEvents) {
      _stopNoteOnChannel(event.pitch, event.channel);
    }

    for (final event in onEvents) {
      _playNoteOnChannel(event.pitch, event.channel, event.isDrums);
    }
  }

  Future<void> _playNoteOnChannel(int pitch, int channel, bool isDrums) async {
    try {
      await _midiEngine?.playNote(
        note: pitch,
        velocity: isDrums ? 110 : 90,
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