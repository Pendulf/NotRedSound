import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
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

class _PianoRollScreenState extends State<PianoRollScreen> {
  late Track currentTrack;

  final AudioService _audioService = AudioService();
  late VoiceRecorderService _voiceRecorder;

  bool _isPlaying = false;
  bool _isRecordingVoice = false;

  late ScrollController _timeScaleController;
  late ScrollController _verticalScrollController;

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;
  late int ticksPerBar;

  static const int minNote = AppConstants.minNote;
  static const int maxNote = AppConstants.maxNote;

  int? _pendingStartTick;
  int? _pendingPitch;

  Timer? _nrPulseTimer;
  bool _nrPulseOn = false;
  bool _nrMetronomeEnabled = false;

  List<MidiNote>? _lastVoiceImportBatch;

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

    _audioService.stopPlayback();
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      final notes = await _voiceRecorder.stopRecording();

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
      setState(() {
        _isRecordingVoice = true;
      });
    } catch (_) {}
  }

  void _onVoiceNotesDetected(List<VoiceNote> notes) {
    setState(() {
      final importedBatch = <MidiNote>[];

      for (final voiceNote in notes) {
        if (voiceNote.pitch < minNote || voiceNote.pitch > maxNote) continue;

        final endTick = voiceNote.startTick + voiceNote.durationTicks;
        if (voiceNote.startTick < 0 || endTick > maxTicks) continue;

        final hasConflict = currentTrack.notes.any(
          (note) =>
              note.pitch == voiceNote.pitch &&
              note.intersectsRange(voiceNote.startTick, endTick),
        );

        if (!hasConflict) {
          final newNote = MidiNote(
            pitch: voiceNote.pitch,
            startTick: voiceNote.startTick,
            durationTicks: voiceNote.durationTicks,
          );

          currentTrack.notes.add(newNote);
          importedBatch.add(newNote);
        }
      }

      if (importedBatch.isNotEmpty) {
        _lastVoiceImportBatch = importedBatch;
      }

      _sortNotes();
      widget.onTrackUpdated(currentTrack);
    });
  }

  void _undoLastVoiceImport() {
    final batch = _lastVoiceImportBatch;
    if (batch == null || batch.isEmpty || _isPlaying || _isRecordingVoice) {
      return;
    }

    setState(() {
      currentTrack.notes.removeWhere((note) {
        return batch.any(
          (added) =>
              added.pitch == note.pitch &&
              added.startTick == note.startTick &&
              added.durationTicks == note.durationTicks,
        );
      });

      _lastVoiceImportBatch = null;
      _sortNotes();
      widget.onTrackUpdated(currentTrack);
    });
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
        currentTrack.notes.remove(existingNote);
        _clearPendingSelection();
        _sortNotes();
        widget.onTrackUpdated(currentTrack);
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

      currentTrack.notes.add(
        MidiNote(
          pitch: midiNote,
          startTick: actualStart,
          durationTicks: durationTicks,
        ),
      );

      _sortNotes();
      widget.onTrackUpdated(currentTrack);

      _previewNote(midiNote, durationTicks);
      _clearPendingSelection();
    });
  }

  void _clearAllNotes() {
    if (_isPlaying) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
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
                currentTrack.notes.clear();
                _lastVoiceImportBatch = null;
                _clearPendingSelection();
              });
              widget.onTrackUpdated(currentTrack);
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

  void _scrollLeft() {
    if (_timeScaleController.hasClients) {
      final newOffset = (_timeScaleController.offset - AppConstants.barWidth)
          .clamp(0.0, _timeScaleController.position.maxScrollExtent);

      _timeScaleController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollRight() {
    if (_timeScaleController.hasClients) {
      final newOffset = (_timeScaleController.offset + AppConstants.barWidth)
          .clamp(0.0, _timeScaleController.position.maxScrollExtent);

      _timeScaleController.animateTo(
        newOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildRoundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    String? tooltip,
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
        tooltip: tooltip,
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

  Widget _buildBottomToolbar() {
    final canUndo = _lastVoiceImportBatch != null &&
        _lastVoiceImportBatch!.isNotEmpty &&
        !_isPlaying &&
        !_isRecordingVoice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoundButton(
            icon: Icons.undo,
            onPressed: canUndo ? _undoLastVoiceImport : null,
            color: currentTrack.color,
            tooltip: 'Удалить последнюю запись',
          ),
          const SizedBox(width: 40),
          _buildRoundButton(
            icon: _isPlaying ? Icons.stop : Icons.play_arrow,
            onPressed: _togglePlayback,
            color: currentTrack.color,
            tooltip: _isPlaying ? 'Стоп' : 'Воспроизвести',
          ),
          const SizedBox(width: 40),
          _buildRoundButton(
            icon: _isRecordingVoice ? Icons.mic : Icons.mic_none,
            onPressed: _toggleVoiceRecording,
            color: currentTrack.color,
            tooltip: _isRecordingVoice ? 'Остановить запись' : 'Записать голос',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playheadTick = _audioService.currentTick;
    final horizontalOffset =
        _timeScaleController.hasClients ? _timeScaleController.offset : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          currentTrack.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: currentTrack.color,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _buildRoundButton(
            icon: Icons.delete,
            onPressed: _clearAllNotes,
            color: currentTrack.color,
            tooltip: 'Очистить все ноты',
          ),
          const SizedBox(width: 12),
        ],
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
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[900]!),
                  ),
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

                        return Container(
                          width: AppConstants.noteCellWidth,
                          decoration: BoxDecoration(
                            color: playheadTick == index
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
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
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
                                  bottom:
                                      BorderSide(color: Colors.grey.shade800),
                                  right:
                                      BorderSide(color: Colors.grey.shade700),
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
                                  final viewportWidth = constraints.maxWidth;
                                  final firstVisibleTick = (horizontalOffset /
                                          AppConstants.noteCellWidth)
                                      .floor()
                                      .clamp(0, maxTicks - 1);
                                  final visibleTickCount = (viewportWidth /
                                              AppConstants.noteCellWidth)
                                          .ceil() +
                                      2;
                                  final lastVisibleTick =
                                      (firstVisibleTick + visibleTickCount)
                                          .clamp(0, maxTicks);

                                  final cells = <Widget>[];
                                  for (int tickIndex = firstVisibleTick;
                                      tickIndex < lastVisibleTick;
                                      tickIndex++) {
                                    final isNotePresent =
                                        _isNotePresent(midiNote, tickIndex);
                                    final isPending =
                                        _isPendingCell(midiNote, tickIndex);

                                    cells.add(
                                      Positioned(
                                        left: (tickIndex *
                                                AppConstants.noteCellWidth) -
                                            horizontalOffset,
                                        top: 0,
                                        width: AppConstants.noteCellWidth,
                                        height: 30,
                                        child: GestureDetector(
                                          onTap: () =>
                                              _handleTap(midiNote, tickIndex),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isPending
                                                  ? Colors.lightGreen
                                                      .withValues(alpha: 0.55)
                                                  : isNotePresent
                                                      ? currentTrack.color
                                                          .withValues(
                                                              alpha: 0.78)
                                                      : Colors.transparent,
                                              border: Border(
                                                right: BorderSide(
                                                  color: _getLineColor(
                                                      tickIndex + 1),
                                                  width: _getLineWidth(
                                                      tickIndex + 1),
                                                ),
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade800,
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
            const SizedBox(height: 12),
            _buildBottomToolbar(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
