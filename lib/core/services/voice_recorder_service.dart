// lib/core/services/voice_recorder_service.dart
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

class VoiceRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamController<Uint8List>? _streamController;
  StreamSubscription<Uint8List>? _streamSubscription;
  bool _isRecording = false;
  DateTime? _startTime;
  
  final List<double> _buffer = [];
  
  // Для каждого сегмента 4/16 собираем статистику по нотам
  final Map<int, Map<int, int>> _segmentNoteCounts = {}; // segmentIndex -> {note: count}
  int _currentSegmentIndex = 0;
  
  // Результирующие сегменты с одной нотой
  final List<VoiceSegment> _segments = [];
  
  // Коллбэки
  Function(List<VoiceNote> notes)? onNotesDetected;
  Function(double progress)? onProgress;
  
  // Параметры анализа
  static const int sampleRate = 44100;
  static const int analysisWindowSize = 8820; // 0.2 секунды для анализа частоты
  static const int hopSize = 2205; // 0.05 секунды шаг (для более частого анализа)
  
  // Константы для длительности сегмента (4/16)
  static const double segmentDurationSeconds = 0.25; // 4/16 при 60 BPM (1/4 секунды)
  static const int ticksPerSegment = 4; // 4 тика (1/16 каждый)
  
  bool get isRecording => _isRecording;
  
  Future<bool> requestPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      
      await _recorder.openRecorder();
    } catch (e) {
      debugPrint('Ошибка инициализации аудио сессии: $e');
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
    
    // Анализируем с маленьким шагом
    while (_buffer.length >= analysisWindowSize) {
      final chunk = _buffer.sublist(0, analysisWindowSize);
      _buffer.removeRange(0, hopSize);
      
      _analyzeChunk(chunk);
    }
  }
  
  void _analyzeChunk(List<double> chunk) {
    // Проверяем громкость
    final rms = sqrt(chunk.fold<double>(0, (sum, x) => sum + x * x) / chunk.length);
    
    // Определяем текущее время в секундах от начала записи
    final currentTime = DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;
    
    // Определяем индекс текущего сегмента (4/16)
    final segmentIndex = (currentTime / segmentDurationSeconds).floor();
    
    // Если перешли в новый сегмент, финализируем предыдущий
    if (segmentIndex != _currentSegmentIndex) {
      _finalizeSegment(_currentSegmentIndex);
    }
    
    _currentSegmentIndex = segmentIndex;
    
    // Если тихо - просто пропускаем (не добавляем в статистику)
    if (rms < 0.02) {
      return;
    }
    
    // Детектируем частоту
    final freq = _detectPitch(chunk, sampleRate);
    if (freq == null) return;
    
    final midiNote = _frequencyToMidi(freq);
    if (midiNote < 48 || midiNote > 84) return; // Ограничиваем диапазон C3-C6
    
    // Добавляем ноту в статистику текущего сегмента
    _segmentNoteCounts.putIfAbsent(segmentIndex, () => {});
    _segmentNoteCounts[segmentIndex]![midiNote] = 
        (_segmentNoteCounts[segmentIndex]![midiNote] ?? 0) + 1;
    
    // Обновляем прогресс
    onProgress?.call(currentTime);
  }
  
  void _finalizeSegment(int segmentIndex) {
    // Если нет данных для этого сегмента, пропускаем
    if (!_segmentNoteCounts.containsKey(segmentIndex)) {
      return;
    }
    
    final noteCounts = _segmentNoteCounts[segmentIndex]!;
    
    // Если есть ноты в сегменте, выбираем самую частую
    if (noteCounts.isNotEmpty) {
      // Находим ноту с максимальным количеством вхождений
      int bestNote = -1;
      int maxCount = 0;
      
      noteCounts.forEach((note, count) {
        if (count > maxCount) {
          maxCount = count;
          bestNote = note;
        }
      });
      
      // Добавляем сегмент с выбранной нотой
      if (bestNote != -1) {
        _segments.add(VoiceSegment(
          pitch: bestNote,
          startTick: segmentIndex * ticksPerSegment,
          durationTicks: ticksPerSegment,
        ));
        
        debugPrint('✅ Сегмент $segmentIndex: нота $bestNote (встречаемость: $maxCount)');
      }
    }
    
    // Очищаем статистику для этого сегмента
    _segmentNoteCounts.remove(segmentIndex);
  }
  
  double? _detectPitch(List<double> samples, int sr) {
    final size = samples.length;
    final maxLag = min(1000, size ~/ 2);
    double bestCorr = 0;
    int bestLag = 0;
    
    for (var lag = 50; lag < maxLag; lag++) {
      var corr = 0.0;
      for (var i = 0; i < size - lag; i++) {
        corr += samples[i] * samples[i + lag];
      }
      if (corr > bestCorr) {
        bestCorr = corr;
        bestLag = lag;
      }
    }
    
    if (bestLag == 0) return null;
    final freq = sr / bestLag;
    return (freq < 80 || freq > 1000) ? null : freq;
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
  
  // Финализируем последний сегмент
  _finalizeSegment(_currentSegmentIndex);
  
  // Очищаем оставшиеся сегменты (если есть)
  _segmentNoteCounts.clear();
  
  // Объединяем последовательные сегменты с одинаковой нотой
  var notes = _mergeSegments();
  
  // Сдвигаем все ноты так, чтобы первая нота начиналась с 0
  notes = _shiftNotesToStart(notes);
  
  _isRecording = false;
  
  if (onNotesDetected != null) {
    onNotesDetected!(notes);
  }
  
  return notes;
}

List<VoiceNote> _shiftNotesToStart(List<VoiceNote> notes) {
  if (notes.isEmpty) return notes;
  
  // Находим минимальный startTick среди всех нот
  int minStartTick = notes.map((note) => note.startTick).reduce((a, b) => a < b ? a : b);
  
  debugPrint('📊 Минимальный startTick: $minStartTick');
  
  // Если первая нота уже начинается с 0, ничего не делаем
  if (minStartTick == 0) return notes;
  
  // Сдвигаем все ноты
  final shiftedNotes = <VoiceNote>[];
  for (var note in notes) {
    shiftedNotes.add(VoiceNote(
      pitch: note.pitch,
      startTick: note.startTick - minStartTick, // Сдвигаем к началу
      durationTicks: note.durationTicks,
    ));
  }
  
  debugPrint('➡️ Ноты сдвинуты на $minStartTick тиков к началу');
  
  return shiftedNotes;
}
  
  List<VoiceNote> _mergeSegments() {
    if (_segments.isEmpty) return [];
    
    // Сортируем сегменты по startTick
    _segments.sort((a, b) => a.startTick.compareTo(b.startTick));
    
    final notes = <VoiceNote>[];
    VoiceNote? currentNote;
    
    for (var segment in _segments) {
      if (currentNote == null) {
        currentNote = VoiceNote(
          pitch: segment.pitch,
          startTick: segment.startTick,
          durationTicks: segment.durationTicks,
        );
      } else if (currentNote.pitch == segment.pitch) {
        // Продолжаем ту же ноту - объединяем
        currentNote.durationTicks += segment.durationTicks;
      } else {
        // Завершаем текущую ноту и начинаем новую
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
    
    // Выводим отладочную информацию
    for (var note in notes) {
      debugPrint('🎵 Итоговая нота: ${note.pitch} с тика ${note.startTick} длительность ${note.durationTicks}');
    }
    
    return notes;
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