class VoiceNoteEntity {
  int pitch;
  int startTick;
  int durationTicks;
  final double? sourceFrequencyHz;

  VoiceNoteEntity({
    required this.pitch,
    required this.startTick,
    required this.durationTicks,
    this.sourceFrequencyHz,
  });
}
