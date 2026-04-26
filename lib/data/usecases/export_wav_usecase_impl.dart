import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/track_entity.dart';

class ExportWavUseCaseImpl {
  static const int _sampleRate = 44100;
  static const int _channels = 2;
  static const int _bitsPerSample = 16;
  static const double _tailSeconds = 1.2;

  Future<void> execute(
    List<TrackEntity> tracks, {
    String? fileName,
    int bpm = 120,
  }) async {
    if (tracks.isEmpty) {
      throw Exception('Нет дорожек для экспорта');
    }

    final playableTracks = tracks
        .where((track) => !track.isMuted && track.notes.isNotEmpty)
        .toList();

    if (playableTracks.isEmpty) {
      throw Exception('Нет активных дорожек с нотами для WAV экспорта');
    }

    final wavData = _renderProjectToWav(playableTracks, bpm);
    final resolvedFileName = fileName ?? _defaultFileName(playableTracks);

    await _shareWav(wavData, resolvedFileName);
  }

  Uint8List _renderProjectToWav(List<TrackEntity> tracks, int bpm) {
    final safeBpm = bpm.clamp(40, 240).toInt();
    final secondsPerTick = (60.0 / safeBpm) / AppConstants.ticksPerBeat;

    int maxEndTick = 0;
    for (final track in tracks) {
      for (final note in track.notes) {
        if (note.endTick > maxEndTick) {
          maxEndTick = note.endTick;
        }
      }
    }

    final totalSeconds = (maxEndTick * secondsPerTick) + _tailSeconds;
    final totalFrames = math.max(1, (totalSeconds * _sampleRate).ceil());
    final mixBuffer = Float32List(totalFrames * _channels);

    for (int trackIndex = 0; trackIndex < tracks.length; trackIndex++) {
      final track = tracks[trackIndex];
      final pan = _panForTrack(trackIndex, tracks.length);
      final isDrums = _isDrumTrack(track);
      final trackGain = (track.volume.clamp(0.0, 1.0)).toDouble();

      for (final note in track.notes) {
        if (note.durationTicks <= 0) continue;

        final startFrame = (note.startTick * secondsPerTick * _sampleRate)
            .round()
            .clamp(0, totalFrames - 1)
            .toInt();

        final noteFrames = (note.durationTicks * secondsPerTick * _sampleRate)
            .round()
            .clamp(1, totalFrames)
            .toInt();

        if (isDrums) {
          _renderDrum(
            buffer: mixBuffer,
            startFrame: startFrame,
            pitch: note.pitch,
            volume: trackGain,
            pan: pan,
          );
        } else {
          _renderTone(
            buffer: mixBuffer,
            startFrame: startFrame,
            noteFrames: noteFrames,
            midiPitch: note.pitch,
            instrument: track.instrument,
            volume: trackGain,
            pan: pan,
          );
        }
      }
    }

    _applyVerySmallGlobalFades(mixBuffer);
    return _encodePcm16Wav(mixBuffer);
  }

  bool _isDrumTrack(TrackEntity track) {
    final instrument = track.instrument.toLowerCase();
    final name = track.name.toLowerCase();

    return instrument == 'ударные' ||
        instrument.contains('бочка') ||
        instrument.contains('том') ||
        instrument.contains('перкус') ||
        name.contains('барабан') ||
        name.contains('drum');
  }

  double _panForTrack(int index, int count) {
    if (count <= 1) return 0.0;
    final normalized = (index / (count - 1)) * 2.0 - 1.0;
    return normalized.clamp(-0.28, 0.28).toDouble();
  }

  double _midiFrequency(int pitch) {
    return 440.0 * math.pow(2.0, (pitch - 69) / 12.0).toDouble();
  }

  void _renderTone({
    required Float32List buffer,
    required int startFrame,
    required int noteFrames,
    required int midiPitch,
    required String instrument,
    required double volume,
    required double pan,
  }) {
    final lowerInstrument = instrument.toLowerCase();
    final frequency = _midiFrequency(midiPitch.clamp(0, 127).toInt());
    final releaseFrames = (_releaseSecondsForInstrument(lowerInstrument) *
            _sampleRate)
        .round()
        .clamp(256, _sampleRate)
        .toInt();
    final renderFrames = noteFrames + releaseFrames;
    final maxFrames = buffer.length ~/ _channels;

    final leftGain = math.cos((pan + 1.0) * math.pi / 4.0);
    final rightGain = math.sin((pan + 1.0) * math.pi / 4.0);
    final gain = _baseGainForInstrument(lowerInstrument) * volume;

    for (int i = 0; i < renderFrames; i++) {
      final frame = startFrame + i;
      if (frame < 0 || frame >= maxFrames) break;

      final t = i / _sampleRate;
      final phase = 2.0 * math.pi * frequency * t;
      final envelope = _toneEnvelope(
        frameOffset: i,
        noteFrames: noteFrames,
        releaseFrames: releaseFrames,
        instrument: lowerInstrument,
      );

      final rawSample = _oscillator(phase, lowerInstrument, t);
      final sample = rawSample * envelope * gain;
      final bufferIndex = frame * _channels;
      buffer[bufferIndex] += (sample * leftGain).toDouble();
      buffer[bufferIndex + 1] += (sample * rightGain).toDouble();
    }
  }

  double _oscillator(double phase, String instrument, double t) {
    final sine = math.sin(phase);

    if (_containsAny(instrument, ['бас', 'bass'])) {
      return (sine * 0.76) + (math.sin(phase * 2.0) * 0.14);
    }

    if (_containsAny(instrument, ['волна квадрат', 'квадрат', 'моносинт'])) {
      // Не используем жёсткий sign(sin), потому что он даёт резкие фронты и треск.
      final softSquare = _softClip(sine * 4.0);
      return (softSquare * 0.62) + (sine * 0.18);
    }

    if (_containsAny(instrument, ['волна пила', 'пила', 'синт', 'полисинт'])) {
      final cycle = (phase / (2.0 * math.pi)) % 1.0;
      final saw = (cycle * 2.0) - 1.0;
      final softenedSaw = _softClip(saw * 1.8);
      return (softenedSaw * 0.42) + (sine * 0.34);
    }

    if (_containsAny(instrument, ['орган', 'хор', 'струн', 'скрип', 'виолон'])) {
      return (sine * 0.64) +
          (math.sin(phase * 2.0) * 0.16) +
          (math.sin(phase * 3.0) * 0.07);
    }

    if (_containsAny(instrument, ['гитара', 'guitar'])) {
      final pluck = math.exp(-t * 4.5);
      return ((sine * 0.60) +
              (math.sin(phase * 2.0) * 0.18) +
              (math.sin(phase * 3.0) * 0.08)) *
          (0.42 + pluck);
    }

    if (_containsAny(instrument, ['колок', 'челеста', 'маримба', 'кристалл'])) {
      return (sine * 0.66) +
          (math.sin(phase * 2.01) * 0.17) +
          (math.sin(phase * 3.03) * 0.09);
    }

    // Piano-like default.
    return (sine * 0.72) +
        (math.sin(phase * 2.0) * 0.14) +
        (math.sin(phase * 3.0) * 0.06);
  }

  double _baseGainForInstrument(String instrument) {
    if (_containsAny(instrument, ['бас', 'bass'])) return 0.20;
    if (_containsAny(instrument, ['орган', 'хор', 'струн'])) return 0.14;
    if (_containsAny(instrument, ['гитара'])) return 0.16;
    if (_containsAny(instrument, ['синт', 'волна'])) return 0.14;
    if (_containsAny(instrument, ['колок', 'челеста', 'маримба'])) return 0.15;
    return 0.15;
  }

  double _releaseSecondsForInstrument(String instrument) {
    if (_containsAny(instrument, ['орган', 'хор', 'струн'])) return 0.28;
    if (_containsAny(instrument, ['колок', 'челеста', 'кристалл'])) return 0.42;
    if (_containsAny(instrument, ['бас'])) return 0.10;
    if (_containsAny(instrument, ['гитара'])) return 0.16;
    return 0.18;
  }

  double _toneEnvelope({
    required int frameOffset,
    required int noteFrames,
    required int releaseFrames,
    required String instrument,
  }) {
    final attackFrames = _attackFramesForInstrument(instrument);
    final attack = _smoothStep(
      frameOffset / math.max(1, attackFrames),
    );

    if (frameOffset < noteFrames) {
      final progress = noteFrames <= 0
          ? 1.0
          : (frameOffset / noteFrames).clamp(0.0, 1.0).toDouble();

      return attack * _holdEnvelope(progress, instrument);
    }

    final releaseOffset = frameOffset - noteFrames;
    if (releaseFrames <= 0) return 0.0;

    final releaseProgress = (releaseOffset / releaseFrames)
        .clamp(0.0, 1.0)
        .toDouble();

    // Важно: release начинается с того же уровня, на котором закончилась нота.
    // Без этого был скачок громкости в момент отпускания, который слышался как щелчок.
    final endLevel = _holdEnvelope(1.0, instrument);
    final releaseCurve = math.pow(1.0 - releaseProgress, 2.0).toDouble();
    return endLevel * releaseCurve;
  }

  int _attackFramesForInstrument(String instrument) {
    final seconds = _containsAny(instrument, ['орган', 'хор', 'струн'])
        ? 0.035
        : _containsAny(instrument, ['бас'])
            ? 0.010
            : 0.012;

    return math.max(1, (seconds * _sampleRate).round());
  }

  double _holdEnvelope(double progress, String instrument) {
    if (_containsAny(instrument, ['орган', 'хор', 'струн', 'синт'])) {
      return 0.78 + (0.22 * (1.0 - progress));
    }

    if (_containsAny(instrument, ['бас'])) {
      return 0.62 + (0.38 * math.exp(-progress * 1.2));
    }

    if (_containsAny(instrument, ['колок', 'челеста', 'кристалл'])) {
      return math.exp(-progress * 2.4);
    }

    if (_containsAny(instrument, ['гитара'])) {
      return 0.18 + (0.82 * math.exp(-progress * 2.0));
    }

    return 0.24 + (0.76 * math.exp(-progress * 1.7));
  }

  void _renderDrum({
    required Float32List buffer,
    required int startFrame,
    required int pitch,
    required double volume,
    required double pan,
  }) {
    final maxFrames = buffer.length ~/ _channels;
    final random = math.Random((pitch * 1000003) ^ startFrame);

    final isKick = pitch <= 38 || pitch == 60;
    final isHat = pitch >= 46 && pitch <= 60;
    final durationSeconds = isKick
        ? 0.40
        : isHat
            ? 0.14
            : 0.26;
    final renderFrames = math.max(1, (durationSeconds * _sampleRate).round());

    final leftGain = math.cos((pan + 1.0) * math.pi / 4.0);
    final rightGain = math.sin((pan + 1.0) * math.pi / 4.0);
    final gain = (isKick ? 0.34 : 0.24) * volume;

    double previousNoise = 0.0;

    for (int i = 0; i < renderFrames; i++) {
      final frame = startFrame + i;
      if (frame < 0 || frame >= maxFrames) break;

      final t = i / _sampleRate;
      final progress = (i / renderFrames).clamp(0.0, 1.0).toDouble();
      final attack = _smoothStep(i / math.max(1.0, _sampleRate * 0.003));
      final releaseFade = _smoothStep((renderFrames - i) /
          math.max(1.0, _sampleRate * 0.006));
      final envelope = attack *
          releaseFade *
          math.exp(-progress * (isHat ? 9.0 : 5.8));

      final rawNoise = (random.nextDouble() * 2.0) - 1.0;
      final noiseSmoothing = isHat ? 0.18 : 0.62;
      previousNoise = (previousNoise * noiseSmoothing) +
          (rawNoise * (1.0 - noiseSmoothing));

      double sample;
      if (isKick) {
        final freq = 92.0 - (48.0 * progress);
        final body = math.sin(2.0 * math.pi * freq * t) * 0.92;
        final click = previousNoise * math.exp(-progress * 42.0) * 0.08;
        sample = body + click;
      } else if (isHat) {
        final metallic = math.sin(2.0 * math.pi * 7200.0 * t) * 0.16;
        sample = (previousNoise * 0.64) + metallic;
      } else {
        final tone = math.sin(2.0 * math.pi * 185.0 * t) * 0.28;
        sample = (previousNoise * 0.48) + tone;
      }

      sample = _softClip(sample) * envelope * gain;

      final bufferIndex = frame * _channels;
      buffer[bufferIndex] += (sample * leftGain).toDouble();
      buffer[bufferIndex + 1] += (sample * rightGain).toDouble();
    }
  }

  void _applyVerySmallGlobalFades(Float32List samples) {
    final frameCount = samples.length ~/ _channels;
    if (frameCount <= 1) return;

    final fadeFrames = math.min(frameCount ~/ 2, (_sampleRate * 0.010).round());
    if (fadeFrames <= 1) return;

    for (int frame = 0; frame < fadeFrames; frame++) {
      final fadeIn = _smoothStep(frame / fadeFrames);
      final fadeOut = _smoothStep((fadeFrames - frame) / fadeFrames);
      final startIndex = frame * _channels;
      final endIndex = (frameCount - 1 - frame) * _channels;

      for (int channel = 0; channel < _channels; channel++) {
        samples[startIndex + channel] *= fadeIn;
        samples[endIndex + channel] *= fadeOut;
      }
    }
  }

  Uint8List _encodePcm16Wav(Float32List samples) {
    final frameCount = samples.length ~/ _channels;
    final dataSize = frameCount * _channels * (_bitsPerSample ~/ 8);
    final fileSize = 44 + dataSize;
    final bytes = Uint8List(fileSize);
    final data = ByteData.view(bytes.buffer);

    void writeAscii(int offset, String text) {
      for (int i = 0; i < text.length; i++) {
        bytes[offset + i] = text.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, _channels, Endian.little);
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(
      28,
      _sampleRate * _channels * (_bitsPerSample ~/ 8),
      Endian.little,
    );
    data.setUint16(32, _channels * (_bitsPerSample ~/ 8), Endian.little);
    data.setUint16(34, _bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    double peak = 0.0;
    for (final sample in samples) {
      final absValue = sample.abs();
      if (absValue > peak) peak = absValue;
    }

    // Оставляем запас по громкости. Если нормализовать почти до 0 dB,
    // на телефоне и в мессенджерах часто появляется цифровой хруст.
    final normalizeGain = peak > 0.82 ? 0.82 / peak : 1.0;
    int offset = 44;

    for (final sample in samples) {
      final limited = _softClip(sample * normalizeGain * 1.08);
      final value = limited.clamp(-0.98, 0.98).toDouble();
      final intValue = (value * 32767.0).round().clamp(-32768, 32767).toInt();
      data.setInt16(offset, intValue, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  double _smoothStep(double value) {
    final x = value.clamp(0.0, 1.0).toDouble();
    return x * x * (3.0 - (2.0 * x));
  }

  double _softClip(double value) {
    // Мягкий лимитер без dart:math tanh: сохраняет форму тише,
    // но не даёт резких клипов при суммировании дорожек.
    return (2.0 / math.pi) * math.atan(value * 1.35);
  }

  bool _containsAny(String source, List<String> values) {
    for (final value in values) {
      if (source.contains(value)) return true;
    }
    return false;
  }

  String _defaultFileName(List<TrackEntity> tracks) {
    if (tracks.length == 1) {
      return '${_sanitizeFileName(tracks.first.name)}.wav';
    }

    return 'NotRedSound_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  String _sanitizeFileName(String name) {
    const cyrillicToLatin = {
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'e',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'kh',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sch',
      'ы': 'y',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
      'А': 'A',
      'Б': 'B',
      'В': 'V',
      'Г': 'G',
      'Д': 'D',
      'Е': 'E',
      'Ё': 'E',
      'Ж': 'Zh',
      'З': 'Z',
      'И': 'I',
      'Й': 'Y',
      'К': 'K',
      'Л': 'L',
      'М': 'M',
      'Н': 'N',
      'О': 'O',
      'П': 'P',
      'Р': 'R',
      'С': 'S',
      'Т': 'T',
      'У': 'U',
      'Ф': 'F',
      'Х': 'Kh',
      'Ц': 'Ts',
      'Ч': 'Ch',
      'Ш': 'Sh',
      'Щ': 'Sch',
      'Ы': 'Y',
      'Э': 'E',
      'Ю': 'Yu',
      'Я': 'Ya',
    };

    final result = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      final char = name[i];
      if (cyrillicToLatin.containsKey(char)) {
        result.write(cyrillicToLatin[char]);
      } else if (RegExp(r'[a-zA-Z0-9\s\-_]').hasMatch(char)) {
        result.write(char);
      } else {
        result.write('_');
      }
    }

    final sanitized = result
        .toString()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-_]'), '');

    return sanitized.isEmpty ? 'NotRedSound' : sanitized;
  }

  Future<void> _shareWav(Uint8List wavData, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(wavData, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'WAV файл из NotRedSound',
    );
  }
}
