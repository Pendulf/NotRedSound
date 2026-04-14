import 'services/voice_recorder_service.dart';

class ScaleAutotune {
  static const List<String> noteNames = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const Map<String, List<int>> scaleModes = {
    'Мажор': [0, 2, 4, 5, 7, 9, 11],
    'Минор': [0, 2, 3, 5, 7, 8, 10],
  };

  static bool isEnabled = true;
  static int selectedRoot = 0;
  static String selectedMode = 'Минор';

  static Set<int> allowedPitchClasses({
    required int root,
    required String mode,
  }) {
    final intervals = scaleModes[mode] ?? scaleModes['Минор']!;
    return intervals.map((i) => (root + i) % 12).toSet();
  }

  static int quantizePitch({
    required int pitch,
    required int minNote,
    required int maxNote,
  }) {
    if (!isEnabled) {
      return pitch.clamp(minNote, maxNote);
    }

    final allowed = allowedPitchClasses(
      root: selectedRoot,
      mode: selectedMode,
    );

    if (allowed.contains(pitch % 12)) {
      return pitch.clamp(minNote, maxNote);
    }

    int? bestPitch;
    int bestDistance = 1 << 30;

    for (int candidate = minNote; candidate <= maxNote; candidate++) {
      if (!allowed.contains(candidate % 12)) continue;

      final distance = (candidate - pitch).abs();

      if (distance < bestDistance) {
        bestDistance = distance;
        bestPitch = candidate;
      } else if (distance == bestDistance && bestPitch != null) {
        if (candidate > pitch && bestPitch < pitch) {
          bestPitch = candidate;
        }
      }
    }

    return (bestPitch ?? pitch).clamp(minNote, maxNote);
  }

  static String currentLabel() {
    if (!isEnabled) {
      return 'Автотюн выключен';
    }
    return '${noteNames[selectedRoot]} $selectedMode';
  }

  static void toggleEnabled() {
    isEnabled = !isEnabled;
  }

  static void setScale({
    required int root,
    required String mode,
  }) {
    selectedRoot = root.clamp(0, 11);
    selectedMode = scaleModes.containsKey(mode) ? mode : 'Минор';
  }

  static Map<String, dynamic>? detectScaleFromVoiceNotes(List<VoiceNote> notes) {
    if (notes.isEmpty) return null;

    final weights = <int, double>{};
    for (final note in notes) {
      final pitchClass = note.pitch % 12;
      final weight = note.durationTicks <= 0 ? 1.0 : note.durationTicks.toDouble();
      weights[pitchClass] = (weights[pitchClass] ?? 0) + weight;
    }

    if (weights.isEmpty) return null;

    double bestScore = -1;
    int bestRoot = 0;
    String bestMode = 'Минор';

    for (final modeEntry in scaleModes.entries) {
      final mode = modeEntry.key;
      final intervals = modeEntry.value.toSet();

      for (int root = 0; root < 12; root++) {
        double score = 0;

        for (final entry in weights.entries) {
          final normalized = (entry.key - root + 12) % 12;
          if (intervals.contains(normalized)) {
            score += entry.value;
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestRoot = root;
          bestMode = mode;
        }
      }
    }

    return {
      'root': bestRoot,
      'mode': bestMode,
      'label': '${noteNames[bestRoot]} $bestMode',
    };
  }
}