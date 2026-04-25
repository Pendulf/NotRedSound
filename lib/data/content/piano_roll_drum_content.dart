class PianoRollDrumContent {
  static const int minDrumNote = 36; // C2
  static const int maxDrumNote = 60; // C4

  static const int kickNote = 36;
  static const int snareNote = 38;
  static const int closedHatNote = 42;

  /// Visible drum rows for the unified Piano Roll drum mode.
  /// The order is top-to-bottom, so the highest note is first.
  static const List<int> c2ToC4VisibleNotes = [
    60,
    59,
    58,
    57,
    56,
    55,
    54,
    53,
    52,
    51,
    50,
    49,
    48,
    47,
    46,
    45,
    44,
    43,
    42,
    41,
    40,
    39,
    38,
    37,
    36,
  ];

  static const Map<int, String> drumLabels = {
    60: 'Hi Bongo',
    59: 'Ride 2',
    58: 'Vibraslap',
    57: 'Crash 2',
    56: 'Cowbell',
    55: 'Splash',
    54: 'Tambourine',
    53: 'Ride Bell',
    52: 'Chinese',
    51: 'Ride 1',
    50: 'High Tom',
    49: 'Crash 1',
    48: 'Hi-Mid Tom',
    47: 'Low-Mid Tom',
    46: 'Open Hat',
    45: 'Low Tom',
    44: 'Pedal Hat',
    43: 'Floor Tom',
    42: 'Closed Hat',
    41: 'Low Floor Tom',
    40: 'Snare 2',
    39: 'Clap',
    38: 'Snare',
    37: 'Rimshot',
    36: 'Kick',
  };

  static String instrumentLabelFor(int midiNote) {
    return drumLabels[midiNote] ?? 'Drum';
  }

  static String labelFor(int midiNote) {
    return instrumentLabelFor(midiNote);
  }
}
