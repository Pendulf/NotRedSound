import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/scale_autotune.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/voice_recorder_service.dart';
import '../../data/models/track_model.dart';

class PianoRollScreen extends StatefulWidget {
  final Track track;
  final Function(Track) onTrackUpdated;
  final int bpm;

  const PianoRollScreen({
    super.key,
    required this.track,
    required this.onTrackUpdated,
    this.bpm = 120,
  });

  @override
  State<PianoRollScreen> createState() => _PianoRollScreenState();
}

class _PianoRollScreenState extends State<PianoRollScreen>
    with SingleTickerProviderStateMixin {
  late Track currentTrack;

  final AudioService _audioService = AudioService();
  late VoiceRecorderService _voiceRecorder;

  bool _isPlaying = false;
  bool _isRecordingVoice = false;

  late ScrollController _timeScaleController;
  late ScrollController _verticalScrollController;
  late AnimationController _micBorderRotationController;

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;
  late int ticksPerBar;

  static const int minNote = AppConstants.minNote;
  static const int maxNote = AppConstants.maxNote;
  static const int octaveShift = 12;

  int? _pendingStartTick;
  int? _pendingPitch;
  int _recordStartTick = 0;

  Timer? _nrPulseTimer;
  bool _nrPulseOn = false;
  bool _nrMetronomeEnabled = false;

  List<MidiNote>? _lastVoiceImportBatch;
  bool _octaveShiftUpMode = true;
  bool _splitMode = false;

  final List<List<MidiNote>> _history = [];

  @override
  void initState() {
    super.initState();

    currentTrack = widget.track;

    maxTicks = AppConstants.maxTicks;
    ticksPerBeat = AppConstants.ticksPerBeat;
    beatsPerBar = AppConstants.beatsPerBar;
    ticksPerBar = AppConstants.ticksPerBar;

    _timeScaleController = ScrollController();
    _verticalScrollController = ScrollController();

    _micBorderRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _timeScaleController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _voiceRecorder = VoiceRecorderService();
    _voiceRecorder.initialize();
    _voiceRecorder.setProjectBpm(widget.bpm);
    _voiceRecorder.mergeRepeatedNotes = false;
    _voiceRecorder.onNotesDetected = _onVoiceNotesDetected;

    _setupTrackInstrument();
  }

  void _setupTrackInstrument() {
    _audioService.setTrackInstrument(currentTrack.id, currentTrack.instrument);
  }

  List<MidiNote> _cloneNotes(List<MidiNote> source) {
    return source
        .map(
          (note) => MidiNote(
            pitch: note.pitch,
            startTick: note.startTick,
            durationTicks: note.durationTicks,
          ),
        )
        .toList();
  }

  void _pushHistory() {
    _history.add(_cloneNotes(currentTrack.notes));
    if (_history.length > 100) {
      _history.removeAt(0);
    }
  }

  void _commitTrackUpdate({bool clearPending = false}) {
    _sortNotes();
    if (clearPending) {
      _clearPendingSelection();
    }
    widget.onTrackUpdated(currentTrack);
  }

  bool get _hasNotes => currentTrack.notes.isNotEmpty;
  bool get _canUndo => _history.isNotEmpty && !_isPlaying && !_isRecordingVoice;

  void _undoLastAction() {
    if (!_canUndo) return;

    final previous = _history.removeLast();

    setState(() {
      currentTrack = currentTrack.copyWith(notes: _cloneNotes(previous));
      _lastVoiceImportBatch = null;
      _clearPendingSelection();
      _commitTrackUpdate();
    });
  }

  void _toggleNrMetronome() {
    if (_nrMetronomeEnabled) {
      _stopNrMetronome();
    } else {
      _startNrMetronome();
    }
    setState(() {});
  }

  void _startNrMetronome() {
    if (_nrMetronomeEnabled) return;

    _nrMetronomeEnabled = true;
    _nrPulseOn = true;

    final beatMs = (60000 / AppConstants.bpm).round();

    _nrPulseTimer?.cancel();
    _nrPulseTimer = Timer.periodic(Duration(milliseconds: beatMs), (_) {
      if (!mounted || !_nrMetronomeEnabled) {
        _stopNrMetronome();
        return;
      }

      setState(() {
        _nrPulseOn = !_nrPulseOn;
      });
    });
  }

  void _stopNrMetronome() {
    _nrMetronomeEnabled = false;
    _nrPulseOn = false;
    _nrPulseTimer?.cancel();
    _nrPulseTimer = null;
  }

  @override
  void dispose() {
    _stopNrMetronome();
    _timeScaleController.dispose();
    _verticalScrollController.dispose();
    _micBorderRotationController.dispose();

    _audioService.stopPlayback();
    _voiceRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      final notes = await _voiceRecorder.stopRecording();

      _micBorderRotationController.stop();

      setState(() {
        _isRecordingVoice = false;
      });

      if (notes.isNotEmpty) {
        _onVoiceNotesDetected(notes);
      }
      return;
    }

    try {
      await _voiceRecorder.startRecording();
      _micBorderRotationController.repeat();

      setState(() {
        _isRecordingVoice = true;
      });
    } catch (_) {}
  }

  void _toggleAutotune() {
    setState(() {
      ScaleAutotune.toggleEnabled();
    });
  }

  int _quantizePitchToScale(int pitch) {
    return ScaleAutotune.quantizePitch(
      pitch: pitch,
      minNote: minNote,
      maxNote: maxNote,
    );
  }

  String _currentScaleLabel() {
    return ScaleAutotune.currentLabel();
  }

  Future<void> _showScalePicker() async {
    final dialogRecorder = VoiceRecorderService();
    await dialogRecorder.initialize();
    dialogRecorder.setProjectBpm(widget.bpm);
    dialogRecorder.mergeRepeatedNotes = false;

    bool isDetecting = false;
    String detectedLabel = ScaleAutotune.currentLabel();

    if (!mounted) {
      dialogRecorder.dispose();
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> toggleDetectRecording() async {
              if (isDetecting) {
                final notes = await dialogRecorder.stopRecording();

                setLocalState(() {
                  isDetecting = false;
                });

                final detected = ScaleAutotune.detectScaleFromVoiceNotes(notes);
                if (detected != null) {
                  ScaleAutotune.setScale(
                    root: detected['root'] as int,
                    mode: detected['mode'] as String,
                  );

                  setLocalState(() {
                    detectedLabel = detected['label'] as String;
                  });

                  if (mounted) {
                    setState(() {});
                  }
                }
                return;
              }

              try {
                await dialogRecorder.startRecording();
                setLocalState(() {
                  isDetecting = true;
                });
              } catch (_) {}
            }

            Widget buildDialogMicButton() {
              return AnimatedBuilder(
                animation: _micBorderRotationController,
                builder: (context, child) {
                  final angle = isDetecting
                      ? _micBorderRotationController.value * 2 * math.pi
                      : 0.0;

                  return Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.purple,
                            Colors.blue,
                            Colors.red,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(2.2),
                      child: Transform.rotate(
                        angle: -angle,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                  colors: [
                    const Color.fromRGBO(224, 67, 54, 1),
                    const Color.fromRGBO(33, 130, 243, 1),
                    const Color.fromRGBO(156, 39, 156, 1),
                    const Color.fromRGBO(224, 67, 54, 1),
                  ],
                ),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              if (isDetecting) {
                                _micBorderRotationController.stop();
                              } else {
                                _micBorderRotationController.repeat();
                              }
                              await toggleDetectRecording();
                            },
                            padding: EdgeInsets.zero,
                            splashRadius: 24,
                            icon: Icon(
                              isDetecting ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: currentTrack.color, width: 2),
              ),
              title: const Text(
                'Тональность',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Спой мелодию, чтобы определить тональность',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  buildDialogMicButton(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Text(
                        'Тональность: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          detectedLabel,
                          style: TextStyle(
                            color: currentTrack.color,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (isDetecting) {
                      await dialogRecorder.stopRecording();
                      _micBorderRotationController.stop();
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogRecorder.dispose();
  }

  void _onVoiceNotesDetected(List<VoiceNote> notes) {
    if (notes.isEmpty) return;

    setState(() {
      _pushHistory();

      final importedBatch = <MidiNote>[];

      for (final voiceNote in notes) {
        final quantizedPitch = _quantizePitchToScale(voiceNote.pitch);
        final shiftedStartTick = voiceNote.startTick + _recordStartTick;

        if (quantizedPitch < minNote || quantizedPitch > maxNote) continue;

        final endTick = shiftedStartTick + voiceNote.durationTicks;
        if (shiftedStartTick < 0 || endTick > maxTicks) continue;

        final hasConflict = currentTrack.notes.any(
          (note) =>
              note.pitch == quantizedPitch &&
              note.intersectsRange(shiftedStartTick, endTick),
        );

        if (!hasConflict) {
          final newNote = MidiNote(
            pitch: quantizedPitch,
            startTick: shiftedStartTick,
            durationTicks: voiceNote.durationTicks,
          );

          currentTrack.notes.add(newNote);
          importedBatch.add(newNote);
        }
      }

      if (importedBatch.isNotEmpty) {
        _lastVoiceImportBatch = importedBatch;
        _commitTrackUpdate(clearPending: true);
      } else {
        _history.removeLast();
      }
    });
  }

  void _toggleOctaveShiftMode() {
    setState(() {
      _octaveShiftUpMode = !_octaveShiftUpMode;
    });
  }

  void _toggleMergeSplitMode() {
    setState(() {
      _splitMode = !_splitMode;
    });
  }

  void _shiftAllNotesByOctave() {
    if (_isPlaying || !_hasNotes) return;

    final shift = _octaveShiftUpMode ? octaveShift : -octaveShift;

    final shiftedNotes = <MidiNote>[];

    for (final note in currentTrack.notes) {
      final newPitch = note.pitch + shift;
      if (newPitch < minNote || newPitch > maxNote) {
        return;
      }

      shiftedNotes.add(
        MidiNote(
          pitch: newPitch,
          startTick: note.startTick,
          durationTicks: note.durationTicks,
        ),
      );
    }

    setState(() {
      _pushHistory();
      currentTrack = currentTrack.copyWith(notes: shiftedNotes);
      _lastVoiceImportBatch = null;
      _commitTrackUpdate(clearPending: true);
    });
  }

  void _mergeAdjacentSameNotes() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    setState(() {
      _pushHistory();
      _sortNotes();

      final merged = <MidiNote>[];
      MidiNote? current;

      for (final note in currentTrack.notes) {
        if (current == null) {
          current = MidiNote(
            pitch: note.pitch,
            startTick: note.startTick,
            durationTicks: note.durationTicks,
          );
          continue;
        }

        final isSamePitch = current.pitch == note.pitch;
        final isAdjacent =
            current.startTick + current.durationTicks == note.startTick;

        if (isSamePitch && isAdjacent) {
          current = MidiNote(
            pitch: current.pitch,
            startTick: current.startTick,
            durationTicks: current.durationTicks + note.durationTicks,
          );
        } else {
          merged.add(current);
          current = MidiNote(
            pitch: note.pitch,
            startTick: note.startTick,
            durationTicks: note.durationTicks,
          );
        }
      }

      if (current != null) {
        merged.add(current);
      }

      currentTrack = currentTrack.copyWith(notes: merged);
      _lastVoiceImportBatch = null;
      _commitTrackUpdate(clearPending: true);
    });
  }

  void _splitAllNotesToSixteenth() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    setState(() {
      _pushHistory();

      final splitNotes = <MidiNote>[];

      for (final note in currentTrack.notes) {
        if (note.durationTicks <= 1) {
          splitNotes.add(
            MidiNote(
              pitch: note.pitch,
              startTick: note.startTick,
              durationTicks: 1,
            ),
          );
          continue;
        }

        for (int i = 0; i < note.durationTicks; i++) {
          splitNotes.add(
            MidiNote(
              pitch: note.pitch,
              startTick: note.startTick + i,
              durationTicks: 1,
            ),
          );
        }
      }

      currentTrack = currentTrack.copyWith(notes: splitNotes);
      _lastVoiceImportBatch = null;
      _commitTrackUpdate(clearPending: true);
    });
  }

  void _handleMergeSplitAction() {
    if (_splitMode) {
      _splitAllNotesToSixteenth();
    } else {
      _mergeAdjacentSameNotes();
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _audioService.stopPlayback();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    if (currentTrack.notes.isEmpty) return;

    _audioService.setTrackInstrument(currentTrack.id, currentTrack.instrument);

    _audioService.startPlayback(
  [currentTrack],
  startTick: _recordStartTick,
  onTick: () {
    if (mounted) setState(() {});
  },
  onFinished: () {
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  },
);

    setState(() {
      _isPlaying = true;
    });
  }

  void _sortNotes() {
    currentTrack.notes.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });
  }

  void _setRecordStartTick(int tick) {
    setState(() {
      _recordStartTick = tick.clamp(0, maxTicks - 1);
    });
  }

  void _handleGridHorizontalDrag(DragUpdateDetails details) {
    if (!_timeScaleController.hasClients) return;

    final maxExtent = _timeScaleController.position.maxScrollExtent;
    final newOffset = (_timeScaleController.offset - details.delta.dx)
        .clamp(0.0, maxExtent);

    _timeScaleController.jumpTo(newOffset);
  }

  MidiNote? _findNoteCovering(int midiNote, int tick) {
    for (final note in currentTrack.notes) {
      if (note.pitch == midiNote && note.containsTick(tick)) {
        return note;
      }
    }
    return null;
  }

  bool _canPlaceNote(int midiNote, int startTick, int durationTicks) {
    final endTick = startTick + durationTicks;
    if (startTick < 0 || endTick > maxTicks) return false;

    for (final note in currentTrack.notes) {
      if (note.pitch != midiNote) continue;
      if (note.intersectsRange(startTick, endTick)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _previewNote(int midiNote, int durationTicks) async {
    await _audioService.playNoteForTrack(currentTrack.id, midiNote);
    Future.delayed(
      Duration(milliseconds: durationTicks * AppConstants.millisecondsPerTick),
      () {
        _audioService.stopNoteForTrack(currentTrack.id, midiNote);
      },
    );
  }

  void _clearPendingSelection() {
    _pendingStartTick = null;
    _pendingPitch = null;
  }

  void _handleTap(int midiNote, int tick) {
    if (_isPlaying) return;

    setState(() {
      final existingNote = _findNoteCovering(midiNote, tick);
      if (existingNote != null) {
        _pushHistory();
        currentTrack.notes.remove(existingNote);
        _lastVoiceImportBatch = null;
        _commitTrackUpdate(clearPending: true);
        return;
      }

      if (_pendingStartTick == null || _pendingPitch == null) {
        _pendingStartTick = tick;
        _pendingPitch = midiNote;
        return;
      }

      if (_pendingPitch != midiNote) {
        _pendingStartTick = tick;
        _pendingPitch = midiNote;
        return;
      }

      final start = _pendingStartTick!;
      final end = tick;

      final actualStart = start <= end ? start : end;
      final actualEnd = start <= end ? end : start;
      final durationTicks = (actualEnd - actualStart) + 1;

      if (!_canPlaceNote(midiNote, actualStart, durationTicks)) {
        _clearPendingSelection();
        return;
      }

      _pushHistory();
      currentTrack.notes.add(
        MidiNote(
          pitch: midiNote,
          startTick: actualStart,
          durationTicks: durationTicks,
        ),
      );

      _lastVoiceImportBatch = null;
      _commitTrackUpdate();

      _previewNote(midiNote, durationTicks);
      _clearPendingSelection();
    });
  }

  void _clearAllNotes() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: currentTrack.color, width: 2),
        ),
        title: const Text(
          'Очистить все ноты',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить все ноты в этой дорожке?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pushHistory();
                currentTrack.notes.clear();
                _lastVoiceImportBatch = null;
                _commitTrackUpdate(clearPending: true);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  String _getOctaveName(int midiNote) {
    if (midiNote % 12 == 0) {
      final octave = (midiNote ~/ 12) - 1;
      return 'C$octave';
    }
    return '';
  }

  bool _isBlackKey(int midiNote) {
    final noteInOctave = midiNote % 12;
    return noteInOctave == 1 ||
        noteInOctave == 3 ||
        noteInOctave == 6 ||
        noteInOctave == 8 ||
        noteInOctave == 10;
  }

  bool _isNotePresent(int midiNote, int tick) {
    return _findNoteCovering(midiNote, tick) != null;
  }

  bool _isPendingCell(int midiNote, int tick) {
    return _pendingPitch == midiNote && _pendingStartTick == tick;
  }

  double _getLineWidth(int tickIndex) {
    if (tickIndex == 0) return 3.0;
    if (tickIndex % ticksPerBar == 0) return 3.0;
    if (tickIndex % ticksPerBeat == 0) return 2.0;
    return 1.0;
  }

  Color _getLineColor(int tickIndex) {
    if (tickIndex % ticksPerBar == 0) return Colors.amber;
    if (tickIndex % ticksPerBeat == 0) {
      return Colors.amber.withValues(alpha: 0.6);
    }
    return Colors.grey.shade700;
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    required Color color,

  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: IconButton(
        onPressed: onPressed,
        onLongPress: onLongPress,
        padding: EdgeInsets.zero,
        splashRadius: 20,
        icon: Icon(
          icon,
          color: Colors.white.withValues(alpha: onPressed == null ? 0.45 : 1.0),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    final outerSize = _isRecordingVoice ? 72.0 : 58.0;
    final ringThickness = _isRecordingVoice ? 3.3 : 2.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      width: outerSize,
      height: outerSize,
      child: AnimatedBuilder(
        animation: _micBorderRotationController,
        builder: (context, child) {
          final angle = _micBorderRotationController.value * 2 * math.pi;

          return Transform.rotate(
            angle: angle,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                
                gradient: SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.purple,
                    Colors.blue,
                    Colors.red,
                  ],
                ),
              ),
              padding: EdgeInsets.all(ringThickness),
              child: Transform.rotate(
                angle: -angle,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                  colors: [
                    const Color.fromRGBO(224, 67, 54, 1),
                    const Color.fromRGBO(33, 130, 243, 1),
                    const Color.fromRGBO(156, 39, 156, 1),
                    const Color.fromRGBO(224, 67, 54, 1),
                  ],
                ),
                    boxShadow: _isRecordingVoice
                        ? [
                            BoxShadow(
                              color: currentTrack.color.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    onPressed: _toggleVoiceRecording,
                    padding: EdgeInsets.zero,
                    splashRadius: 28,
                    icon: Icon(
                      _isRecordingVoice ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: _isRecordingVoice ? 28 : 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOutlinedGradientNr() {
    final duration = Duration(
      milliseconds: (60000 / AppConstants.bpm / 2).round(),
    );

    return GestureDetector(
      onTap: _toggleNrMetronome,
      child: AnimatedScale(
        scale: _nrMetronomeEnabled ? (_nrPulseOn ? 1.5 : 1.0) : 1.0,
        duration: duration,
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _nrMetronomeEnabled ? (_nrPulseOn ? 1.0 : 0.78) : 1.0,
          duration: duration,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: AnimatedContainer(
                  duration: duration,
                  width: _nrPulseOn ? 62 : 50,
                  height: _nrPulseOn ? 34 : 26,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: _nrPulseOn ? 0.30 : 0.18),
                        blurRadius: _nrPulseOn ? 26 : 16,
                        spreadRadius: _nrPulseOn ? 4 : 1,
                      ),
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: _nrPulseOn ? 0.28 : 0.16),
                        blurRadius: _nrPulseOn ? 34 : 20,
                        spreadRadius: _nrPulseOn ? 5 : 2,
                      ),
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: _nrPulseOn ? 0.24 : 0.14),
                        blurRadius: _nrPulseOn ? 42 : 24,
                        spreadRadius: _nrPulseOn ? 6 : 2,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                ' NR',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.5,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.0
                    ..color = currentTrack.color,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.red, Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  ' NR',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutotuneButton() {
    final outerColor =
        ScaleAutotune.isEnabled ? Colors.white : Colors.grey.shade500;
    final innerColor =
        ScaleAutotune.isEnabled ? currentTrack.color : currentTrack.color;

    return GestureDetector(
      onTap: _showScalePicker,
      onLongPress: _toggleAutotune,
      child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: innerColor,
            ),
            child: Icon(
              ScaleAutotune.isEnabled ? Icons.tune : Icons.tune_outlined,
              color: outerColor,
              size: 20,
            ),
          ),
        
      
    );
  }

  Widget _buildBottomToolbar() {
    final notesEnabled = _hasNotes && !_isRecordingVoice;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildRoundButton(
          icon: _splitMode ? Icons.call_split : Icons.merge_type,
          onPressed: notesEnabled ? _handleMergeSplitAction : null,
          onLongPress: notesEnabled ? _toggleMergeSplitMode : null,
          color: currentTrack.color,
        ),
        const SizedBox(width: 20),
        _buildRoundButton(
          icon: Icons.undo,
          onPressed: _canUndo ? _undoLastAction : null,
          color: currentTrack.color,
        ),
        const SizedBox(width: 20),
        _buildMicButton(),
        const SizedBox(width: 20),
        _buildRoundButton(
          icon: _isPlaying ? Icons.stop : Icons.play_arrow,
          onPressed: notesEnabled ? _togglePlayback : null,
          color: currentTrack.color,
        ),
        const SizedBox(width: 20),
        _buildRoundButton(
          icon: _octaveShiftUpMode
              ? Icons.keyboard_double_arrow_up
              : Icons.keyboard_double_arrow_down,
          onPressed: notesEnabled ? _shiftAllNotesByOctave : null,
          onLongPress: notesEnabled ? _toggleOctaveShiftMode : null,
          color: currentTrack.color,
       
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final playheadTick = _audioService.currentTick;
    final horizontalOffset =
        _timeScaleController.hasClients ? _timeScaleController.offset : 0.0;
    final notesEnabled = _hasNotes && !_isRecordingVoice;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[900]);
              },
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
  preferredSize: const Size.fromHeight(86),
  child: SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.horizontalPadding,
        vertical: 8,
      ),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: currentTrack.color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 22,
            ),
            Expanded(
              child: Text(
                currentTrack.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildAutotuneButton(),
            const SizedBox(width: 12),
            _buildRoundButton(
              icon: Icons.delete,
              onPressed: notesEnabled ? _clearAllNotes : null,
              color: currentTrack.color,
            ),
          ],
        ),
      ),
    ),
  ),
),
            body: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.horizontalPadding,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: AppConstants.keyAreaWidth - 7,
                        height: 50,
                        child: Center(
                          child: _buildOutlinedGradientNr(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            controller: _timeScaleController,
                            physics: const ClampingScrollPhysics(),
                            itemCount: maxTicks,
                            itemBuilder: (context, index) {
                              final isBarStart = index % ticksPerBar == 0;
                              final isPlayhead = playheadTick == index;
                              final isRecordStart = _recordStartTick == index;

                              return GestureDetector(
                                onTap: () => _setRecordStartTick(index),
                                child: Container(
                                  width: AppConstants.noteCellWidth,
                                  decoration: BoxDecoration(
                                    color: isPlayhead || isRecordStart
                                        ? Colors.amber.withValues(alpha: 0.18)
                                        : Colors.transparent,
                                    border: Border(
                                      right: BorderSide(
                                        color: _getLineColor(index + 1),
                                        width: _getLineWidth(index + 1),
                                      ),
                                    ),
                                  ),
                                  child: isBarStart
                                      ? Center(
                                          child: Text(
                                            '${index ~/ ticksPerBar + 1}',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: _handleGridHorizontalDrag,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[900]?.withValues(alpha: 0.92),
                        ),
                        child: Scrollbar(
                          controller: _verticalScrollController,
                          child: ListView.builder(
                            controller: _verticalScrollController,
                            itemCount: maxNote - minNote + 1,
                            itemBuilder: (context, noteIndex) {
                              final midiNote = maxNote - noteIndex;
                              final isBlackKey = _isBlackKey(midiNote);
                              final octaveName = _getOctaveName(midiNote);

                              return SizedBox(
                                height: 30,
                                child: Row(
                                  children: [
                                    Container(
                                      width: AppConstants.keyAreaWidth,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade800,
                                          ),
                                          right: BorderSide(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        color: isBlackKey
                                            ? Colors.grey[900]
                                            : Colors.grey[850],
                                      ),
                                      child: Center(
                                        child: octaveName.isNotEmpty
                                            ? Text(
                                                octaveName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: currentTrack.color,
                                                  fontSize: 14,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 30,
                                      color: Colors.amber,
                                    ),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final viewportWidth =
                                              constraints.maxWidth;
                                          final firstVisibleTick =
                                              (horizontalOffset /
                                                      AppConstants.noteCellWidth)
                                                  .floor()
                                                  .clamp(0, maxTicks - 1);
                                          final visibleTickCount =
                                              (viewportWidth /
                                                          AppConstants
                                                              .noteCellWidth)
                                                      .ceil() +
                                                  2;
                                          final lastVisibleTick =
                                              (firstVisibleTick +
                                                      visibleTickCount)
                                                  .clamp(0, maxTicks);

                                          final cells = <Widget>[];
                                          for (int tickIndex = firstVisibleTick;
                                              tickIndex < lastVisibleTick;
                                              tickIndex++) {
                                            final isNotePresent =
                                                _isNotePresent(
                                              midiNote,
                                              tickIndex,
                                            );
                                            final isPending = _isPendingCell(
                                              midiNote,
                                              tickIndex,
                                            );

                                            cells.add(
                                              Positioned(
                                                left: (tickIndex *
                                                        AppConstants
                                                            .noteCellWidth) -
                                                    horizontalOffset,
                                                top: 0,
                                                width:
                                                    AppConstants.noteCellWidth,
                                                height: 30,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: () => _handleTap(
                                                    midiNote,
                                                    tickIndex,
                                                  ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: isPending
                                                          ? Colors.lightGreen
                                                              .withValues(
                                                                alpha: 0.55,
                                                              )
                                                          : isNotePresent
                                                              ? currentTrack
                                                                  .color
                                                                  .withValues(
                                                                    alpha: 0.78,
                                                                  )
                                                              : Colors.transparent,
                                                      border: Border(
                                                        right: BorderSide(
                                                          color: _getLineColor(
                                                            tickIndex + 1,
                                                          ),
                                                          width: _getLineWidth(
                                                            tickIndex + 1,
                                                          ),
                                                        ),
                                                        bottom: BorderSide(
                                                          color: Colors
                                                              .grey.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return SizedBox(
                                            width: viewportWidth,
                                            height: 30,
                                            child: Stack(
                                              clipBehavior: Clip.hardEdge,
                                              children: cells,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBottomToolbar(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}