class NoteRange {
  final int min;
  final int max;

  const NoteRange({
    required this.min,
    required this.max,
  });

  Map<String, int> toMap() => {
        'min': min,
        'max': max,
      };
}
