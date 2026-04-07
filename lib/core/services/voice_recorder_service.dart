import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_constants.dart';

class VoiceRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  StreamController<Uint8List>? _streamController;
  StreamSubscription<Uint8List>? _streamSubscription;

  bool _isRecording = false;
  DateTime? _startTime;

  final List<double> _buffer = [];
  final Map<int, Map<int, int>> _segmentNoteCounts = {};
  final List<VoiceSegment> _segments = [];

  int _currentSegmentIndex = 0;
  int _projectBpm = AppConstants.bpm;

  Function(List<VoiceNote> notes)? onNotesDetected;
  Function(double progress)? onProgress;

  bool mergeRepeatedNotes = false;

  static const int sampleRate = 44100;
  static const int analysisWindowSize = 4096;
  static const int hopSize = 1024;

  bool get isRecording => _isRecording;

  void setProjectBpm(int bpm) {
    _projectBpm = bpm.clamp(40, 240);
  }

  double get _segmentDurationSeconds {
    return (60.0 / _projectBpm) / AppConstants.ticksPerBeat;
  }

  int get _ticksPerSegment => 1;

  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );

      await _recorder.openRecorder();
    } catch (e) {
      debugPrint('Ошибка инициализации voice recorder: $e');
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    if (!await requestPermissions()) {
      throw Exception('Микрофон не доступен');
    }

    _buffer.clear();
    _segmentNoteCounts.clear();
    _segments.clear();
    _currentSegmentIndex = 0;
    _startTime = DateTime.now();

    _streamController = StreamController<Uint8List>();
    _streamSubscription = _streamController!.stream.listen(_processAudio);

    await _recorder.startRecorder(
      toStream: _streamController!.sink,
      codec: Codec.pcm16,
      sampleRate: sampleRate,
      numChannels: 1,
    );

    _isRecording = true;
  }

  void _processAudio(Uint8List buffer) {
    final byteData = ByteData.sublistView(buffer);

    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      _buffer.add(byteData.getInt16(i, Endian.little) / 32768.0);
    }

    while (_buffer.length >= analysisWindowSize) {
      final chunk = _buffer.sublist(0, analysisWindowSize);
      _buffer.removeRange(0, hopSize);
      _analyzeChunk(chunk);
    }
  }

  void _analyzeChunk(List<double> chunk) {
    final rms = sqrt(
      chunk.fold<double>(0, (sum, x) => sum + x * x) / chunk.length,
    );

    if (_startTime == null) return;

    final currentTime =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;

    final segmentIndex = (currentTime / _segmentDurationSeconds).floor();

    if (segmentIndex != _currentSegmentIndex) {
      _finalizeSegment(_currentSegmentIndex);
      _currentSegmentIndex = segmentIndex;
    }

    if (rms < 0.02) {
      onProgress?.call(currentTime);
      return;
    }

    final freq = _detectPitch(chunk, sampleRate);
    if (freq == null) {
      onProgress?.call(currentTime);
      return;
    }

    final midiNote = _frequencyToMidi(freq);
    if (midiNote < AppConstants.minNote || midiNote > AppConstants.maxNote) {
      onProgress?.call(currentTime);
      return;
    }

    _segmentNoteCounts.putIfAbsent(segmentIndex, () => {});
    _segmentNoteCounts[segmentIndex]![midiNote] =
        (_segmentNoteCounts[segmentIndex]![midiNote] ?? 0) + 1;

    onProgress?.call(currentTime);
  }

  void _finalizeSegment(int segmentIndex) {
    if (!_segmentNoteCounts.containsKey(segmentIndex)) return;

    final noteCounts = _segmentNoteCounts[segmentIndex]!;
    if (noteCounts.isEmpty) {
      _segmentNoteCounts.remove(segmentIndex);
      return;
    }

    int bestNote = -1;
    int maxCount = 0;

    noteCounts.forEach((note, count) {
      if (count > maxCount) {
        maxCount = count;
        bestNote = note;
      }
    });

    if (bestNote != -1) {
      _segments.add(
        VoiceSegment(
          pitch: bestNote,
          startTick: segmentIndex * _ticksPerSegment,
          durationTicks: _ticksPerSegment,
        ),
      );
    }

    _segmentNoteCounts.remove(segmentIndex);
  }

  double? _detectPitch(List<double> samples, int sr) {
    final size = samples.length;
    final minLag = (sr / 1000).floor();
    final maxLag = min((sr / 80).floor(), size ~/ 2);

    double bestCorr = 0;
    int bestLag = 0;

    for (int lag = minLag; lag < maxLag; lag++) {
      double corr = 0.0;
      for (int i = 0; i < size - lag; i++) {
        corr += samples[i] * samples[i + lag];
      }

      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }

    if (bestLag == 0) return null;

    final freq = sr / bestLag;
    if (freq < 80 || freq > 1000) return null;

    return freq;
  }

  int _frequencyToMidi(double freq) {
    return (69 + 12 * (log(freq / 440) / ln2)).round();
  }

  Future<List<VoiceNote>> stopRecording() async {
    if (!_isRecording) return [];

    await _recorder.stopRecorder();
    await _streamSubscription?.cancel();
    await _streamController?.close();

    _streamSubscription = null;
    _streamController = null;

    _finalizeSegment(_currentSegmentIndex);
    _segmentNoteCounts.clear();

    var notes = _mergeSegments();
    notes = _smoothNotes(notes);
    notes = _shiftNotesToStart(notes);

    _isRecording = false;

    onNotesDetected?.call(notes);
    return notes;
  }

  List<VoiceNote> _shiftNotesToStart(List<VoiceNote> notes) {
    if (notes.isEmpty) return notes;

    final minStartTick =
        notes.map((note) => note.startTick).reduce((a, b) => a < b ? a : b);

    if (minStartTick == 0) return notes;

    return notes
        .map(
          (note) => VoiceNote(
            pitch: note.pitch,
            startTick: note.startTick - minStartTick,
            durationTicks: note.durationTicks,
          ),
        )
        .toList();
  }

  List<VoiceNote> _mergeSegments() {
    if (_segments.isEmpty) return [];

    _segments.sort((a, b) => a.startTick.compareTo(b.startTick));

    final notes = <VoiceNote>[];
    VoiceNote? currentNote;

    for (final segment in _segments) {
      if (currentNote == null) {
        currentNote = VoiceNote(
          pitch: segment.pitch,
          startTick: segment.startTick,
          durationTicks: segment.durationTicks,
        );
        continue;
      }

      final isSamePitch = currentNote.pitch == segment.pitch;
      final isAdjacent =
          currentNote.startTick + currentNote.durationTicks == segment.startTick;

      if (mergeRepeatedNotes && isSamePitch && isAdjacent) {
        currentNote.durationTicks += segment.durationTicks;
      } else {
        notes.add(currentNote);
        currentNote = VoiceNote(
          pitch: segment.pitch,
          startTick: segment.startTick,
          durationTicks: segment.durationTicks,
        );
      }
    }

    if (currentNote != null) {
      notes.add(currentNote);
    }

    return notes;
  }

  List<VoiceNote> _smoothNotes(List<VoiceNote> notes) {
    if (notes.length < 3) return notes;

    final result = notes
        .map(
          (e) => VoiceNote(
            pitch: e.pitch,
            startTick: e.startTick,
            durationTicks: e.durationTicks,
          ),
        )
        .toList();

    for (int i = 1; i < result.length - 1; i++) {
      final prev = result[i - 1];
      final curr = result[i];
      final next = result[i + 1];

      final currIsShort = curr.durationTicks <= 1;
      final neighborsClose = (prev.pitch - next.pitch).abs() <= 1;
      final currLooksOutlier =
          (curr.pitch - prev.pitch).abs() >= 3 &&
          (curr.pitch - next.pitch).abs() >= 3;

      if (currIsShort && neighborsClose && currLooksOutlier) {
        curr.pitch = ((prev.pitch + next.pitch) / 2).round();
      }
    }

    return result;
  }

  void dispose() {
    _streamSubscription?.cancel();
    _streamController?.close();
    _recorder.closeRecorder();
  }
}

class VoiceSegment {
  final int pitch;
  final int startTick;
  final int durationTicks;

  VoiceSegment({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
  });
}

class VoiceNote {
  int pitch;
  int startTick;
  int durationTicks;

  VoiceNote({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
  });
}