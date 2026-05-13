part of 'piano_roll_screen.dart';

class _PianoRollScreenState extends State<PianoRollScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Track currentTrack;

  final AudioService _audioService = AudioService();
  late VoiceRecorderService _voiceRecorder;

  bool _isPlaying = false;
  bool _isRecordingVoice = false;

  late ScrollController _timeScaleController;
  late ScrollController _verticalScrollController;
  late AnimationController _micBorderRotationController;

  final ValueNotifier<double> _horizontalOffsetNotifier =
      ValueNotifier<double>(0.0);

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;
  late int ticksPerBar;

  static const int minNote = AppConstants.minNote;
  static const int maxNote = AppConstants.maxNote;
  static const int octaveShift = 12;

  late PianoRollEditorController _editor;

  int? get _pendingStartTick => _editor.pendingStartTick;
  set _pendingStartTick(int? value) => _editor.pendingStartTick = value;

  int? get _pendingPitch => _editor.pendingPitch;
  set _pendingPitch(int? value) => _editor.pendingPitch = value;

  int _recordStartTick = 0;

  void _setSelectionStartTick(int? value) {
    _editor.nullableSelectionStartTick = value;
  }

  void _setSelectionEndTick(int? value) {
    _editor.selectionEndTick = value;
  }

  Timer? _nrPulseTimer;
  bool _nrPulseOn = false;
  bool _nrMetronomeEnabled = false;

  bool get _octaveShiftUpMode => _editor.octaveShiftUpMode;
  set _octaveShiftUpMode(bool value) => _editor.octaveShiftUpMode = value;

  bool get _splitMode => _editor.splitMode;
  set _splitMode(bool value) => _editor.splitMode = value;

  List<List<MidiNote>> get _history => _editor.history;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    currentTrack = widget.track;

    maxTicks = AppConstants.maxTicks;
    ticksPerBeat = AppConstants.ticksPerBeat;
    beatsPerBar = AppConstants.beatsPerBar;
    ticksPerBar = AppConstants.ticksPerBar;

    _editor = PianoRollEditorController(
      initialStartTick: widget.initialStartTick,
    );

    _timeScaleController = ScrollController();
    _verticalScrollController = ScrollController();

    _micBorderRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _timeScaleController.addListener(() {
      if (!_timeScaleController.hasClients) return;
      _horizontalOffsetNotifier.value = _timeScaleController.offset;
    });

    _voiceRecorder = VoiceRecorderService();
    _voiceRecorder.initialize();
    _configureVoiceRecorderMode();
    _voiceRecorder.onNotesDetected =
        _PianoRollScreenActions(this)._onVoiceNotesDetected;

    _recordStartTick =
        widget.initialStartTick.clamp(0, math.max(0, maxTicks - 1));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_timeScaleController.hasClients) {
        final targetOffset = _recordStartTick * AppConstants.noteCellWidth;
        final clamped = targetOffset.clamp(
          0.0,
          _timeScaleController.position.maxScrollExtent,
        );
        _timeScaleController.jumpTo(clamped);
        _horizontalOffsetNotifier.value = clamped.toDouble();
      }

      if (_verticalScrollController.hasClients) {
        _scrollToTrackNotes();
      }

      if (mounted) {
        setState(() {});
      }
    });

    _setupTrackInstrument();
  }

  void _setupTrackInstrument() {
    _audioService.setTrackInstrument(currentTrack.id, currentTrack.instrument);
  }

  bool get _isDrumMode => PianoRollDrumUseCases.isDrumTrack(currentTrack);

  List<int> get _visibleMidiNotes {
    if (_isDrumMode) {
      return PianoRollDrumContent.c2ToC4VisibleNotes;
    }

    return List<int>.generate(
      maxNote - minNote + 1,
      (index) => maxNote - index,
      growable: false,
    );
  }

  double get _rollRowHeight => _isDrumMode ? 30.0 : 30.0;

  void _configureVoiceRecorderMode() {
    _voiceRecorder.setProjectBpm(widget.bpm);
    _voiceRecorder.mergeRepeatedNotes = false;

    if (!_isDrumMode) {
      _voiceRecorder.setMelodyRecognitionMode();
    }
  }

  String _labelForPitch(int midiNote) {
    if (_isDrumMode) {
      return PianoRollDrumContent.labelFor(midiNote);
    }

    if (midiNote % 12 == 0) {
      final octave = (midiNote ~/ 12) - 1;
      return 'C$octave';
    }

    return '';
  }

  void _scrollToTrackNotes() {
    if (!_verticalScrollController.hasClients) return;
    if (currentTrack.notes.isEmpty) return;

    final visibleNotes = _visibleMidiNotes;
    if (visibleNotes.isEmpty) return;

    int targetIndex;
    if (_isDrumMode) {
      targetIndex = visibleNotes.indexWhere(
        (pitch) => currentTrack.notes.any((note) => note.pitch == pitch),
      );
      if (targetIndex < 0) targetIndex = visibleNotes.length ~/ 2;
    } else {
      int highestPitch = currentTrack.notes.first.pitch;
      int lowestPitch = currentTrack.notes.first.pitch;

      for (final note in currentTrack.notes) {
        if (note.pitch > highestPitch) highestPitch = note.pitch;
        if (note.pitch < lowestPitch) lowestPitch = note.pitch;
      }

      final centerPitch = ((highestPitch + lowestPitch) / 2).round();
      targetIndex = visibleNotes.indexOf(centerPitch);
      if (targetIndex < 0) {
        targetIndex =
            (maxNote - centerPitch).clamp(0, visibleNotes.length - 1).toInt();
      }
    }

    final rowHeight = _rollRowHeight;
    final viewportHeight = _verticalScrollController.position.viewportDimension;
    final rawOffset =
        (targetIndex * rowHeight) - (viewportHeight / 2) + (rowHeight / 2);

    final clampedOffset = rawOffset.clamp(
      0.0,
      _verticalScrollController.position.maxScrollExtent,
    );

    _verticalScrollController.jumpTo(clampedOffset);
  }

  bool get _hasNotes => currentTrack.notes.isNotEmpty;
  bool get _canUndo => _history.isNotEmpty && !_isPlaying && !_isRecordingVoice;

  @override
  void didUpdateWidget(covariant PianoRollScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id == widget.track.id &&
        oldWidget.track != widget.track) {
      currentTrack = widget.track;
      _setupTrackInstrument();
      _configureVoiceRecorderMode();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_isPlaying) {
        _audioService.stopPlayback();
        _isPlaying = false;
      }

      if (_isRecordingVoice) {
        _voiceRecorder.stopRecording();
        _micBorderRotationController.stop();
        _isRecordingVoice = false;
      }

      _PianoRollScreenActions(this)._stopNrMetronome();

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _PianoRollScreenActions(this)._stopNrMetronome();
    _timeScaleController.dispose();
    _verticalScrollController.dispose();
    _horizontalOffsetNotifier.dispose();
    _micBorderRotationController.dispose();

    _audioService.stopPlayback();
    _voiceRecorder.onNotesDetected = null;
    _voiceRecorder.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback action) {
    if (!mounted) return;
    setState(action);
  }

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) =>
      _PianoRollScreenLogic(this).buildPianoRollScreenContent(context);
}

extension _PianoRollScreenActions on _PianoRollScreenState {
  List<MidiNote> _cloneNotes(List<MidiNote> source) {
    return _editor.cloneNotes(source);
  }

  void _pushHistory() {
    _editor.pushHistory(currentTrack.notes);
  }

  void _commitTrackUpdate({bool clearPending = false}) {
    _sortNotes();
    if (clearPending) {
      _clearPendingSelection();
    }
    widget.onTrackUpdated(currentTrack);
  }

  void _undoLastAction() {
    if (!_canUndo) return;

    final previous = _editor.popUndo();
    if (previous == null) return;

    _safeSetState(() {
      currentTrack = currentTrack.copyWith(notes: _cloneNotes(previous));
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
    _safeSetState(() {});
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

      _safeSetState(() {
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

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      await _voiceRecorder.stopRecording();

      _micBorderRotationController.stop();

      if (!mounted) return;
      _safeSetState(() {
        _isRecordingVoice = false;
      });
      return;
    }

    try {
      await _voiceRecorder.startRecording();
      _micBorderRotationController.repeat();

      _safeSetState(() {
        _isRecordingVoice = true;
      });
    } catch (_) {}
  }

  void _toggleAutotune() {
    _safeSetState(() {
      ScaleAutotune.toggleEnabled();
    });
  }

  void _onVoiceNotesDetected(List<VoiceNote> notes) {
    if (_isDrumMode || notes.isEmpty) return;

    _safeSetState(() {
      _pushHistory();

      final converted = PianoRollVoiceUseCases.convertVoiceNotes(
        voiceNotes: notes,
        insertStartTick: _recordStartTick,
        maxTicks: maxTicks,
      );

      final importedBatch = <MidiNote>[];
      for (final newNote in converted) {
        final hasConflict = currentTrack.notes.any(
          (note) =>
              note.pitch == newNote.pitch &&
              note.intersectsRange(newNote.startTick, newNote.endTick),
        );

        if (!hasConflict) {
          currentTrack.notes.add(newNote);
          importedBatch.add(newNote);
        }
      }

      if (importedBatch.isNotEmpty) {
        _commitTrackUpdate(clearPending: true);
      } else {
        _history.removeLast();
      }
    });
  }

  void _toggleOctaveShiftMode() {
    _safeSetState(() {
      _octaveShiftUpMode = !_octaveShiftUpMode;
    });
  }

  void _toggleMergeSplitMode() {
    _safeSetState(() {
      _splitMode = !_splitMode;
    });
  }

  int? get _selectionRangeStartTick {
    return _editor.selectionRangeStartTick(maxTicks);
  }

  int? get _selectionRangeEndTick {
    return _editor.selectionRangeEndTick(maxTicks);
  }

  bool get _hasDraftSelection => _editor.hasDraftSelection;

  bool get _hasActiveSelection => _editor.hasActiveSelection;

  bool _isTickInDraftSelection(int tick) {
    return _editor.isTickInDraftSelection(tick);
  }

  bool _isTickInActiveSelection(int tick) {
    return _editor.isTickInActiveSelection(tick, maxTicks);
  }

  bool _isBarStartInSelection(int barStartTick) {
    return _isTickInDraftSelection(barStartTick) ||
        _isTickInActiveSelection(barStartTick);
  }

  bool _isNoteInActiveSelection(MidiNote note) {
    return _editor.isNoteInActiveSelection(note, maxTicks);
  }

  List<MidiNote> _selectedNotes() {
    if (!_hasActiveSelection) return [];
    return currentTrack.notes.where(_isNoteInActiveSelection).toList();
  }

  List<MidiNote> _selectedNotesRelativeToSelection() {
    final rangeStart = _selectionRangeStartTick;
    final rangeEnd = _selectionRangeEndTick;
    if (rangeStart == null || rangeEnd == null) return [];

    final result = <MidiNote>[];

    for (final note in currentTrack.notes) {
      if (!note.intersectsRange(rangeStart, rangeEnd)) continue;

      final clippedStart = math.max(note.startTick, rangeStart);
      final clippedEnd = math.min(note.endTick, rangeEnd);
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      result.add(
        MidiNote(
          pitch: note.pitch,
          startTick: clippedStart - rangeStart,
          durationTicks: clippedDuration,
        ),
      );
    }

    PianoRollEditUseCases.sortNotes(result);
    return result;
  }

  List<MidiNote> _replaceNotesInTickRange({
    required List<MidiNote> sourceNotes,
    required int rangeStart,
    required int rangeEnd,
    required List<MidiNote> insertingNotes,
  }) {
    final result = <MidiNote>[];

    for (final note in sourceNotes) {
      if (!note.intersectsRange(rangeStart, rangeEnd)) {
        result.add(note);
        continue;
      }

      if (note.startTick < rangeStart) {
        final leftDuration = rangeStart - note.startTick;
        if (leftDuration > 0) {
          result.add(note.copyWith(durationTicks: leftDuration));
        }
      }

      if (note.endTick > rangeEnd) {
        final rightDuration = note.endTick - rangeEnd;
        if (rightDuration > 0) {
          result.add(
            note.copyWith(
              startTick: rangeEnd,
              durationTicks: rightDuration,
            ),
          );
        }
      }
    }

    result.addAll(insertingNotes);
    PianoRollEditUseCases.sortNotes(result);
    return result;
  }

  void _copyActiveSelectionToTick(int targetTick) {
    final rangeStart = _selectionRangeStartTick;
    final rangeEnd = _selectionRangeEndTick;
    if (rangeStart == null || rangeEnd == null) return;

    final relativeNotes = _selectedNotesRelativeToSelection();
    if (relativeNotes.isEmpty) return;

    final selectionLength = rangeEnd - rangeStart;
    if (selectionLength <= 0) return;

    final targetStart = targetTick.clamp(0, maxTicks - 1).toInt();
    final targetEnd = targetStart + selectionLength;

    if (targetEnd > maxTicks) return;

    final pastedNotes = relativeNotes
        .map(
          (note) => MidiNote(
            pitch: note.pitch,
            startTick: targetStart + note.startTick,
            durationTicks: note.durationTicks,
          ),
        )
        .toList();

    _safeSetState(() {
      _pushHistory();

      currentTrack = currentTrack.copyWith(
        notes: _replaceNotesInTickRange(
          sourceNotes: currentTrack.notes,
          rangeStart: targetStart,
          rangeEnd: targetEnd,
          insertingNotes: pastedNotes,
        ),
      );

      _clearNoteSelection();
      _commitTrackUpdate(clearPending: true);
    });
  }

  void _clearNoteSelection() {
    _editor.clearNoteSelection();
  }

  void _beginNoteSelectionFromTick(int tick) {
    if (_isPlaying) return;

    _safeSetState(() {
      _setSelectionStartTick(tick.clamp(0, maxTicks - 1).toInt());
      _setSelectionEndTick(null);
      _clearPendingSelection();
    });
  }

  void _handleTimeScaleTap(int tick) {
    if (_isPlaying) return;

    if (_hasDraftSelection) {
      _safeSetState(() {
        _setSelectionEndTick(tick.clamp(0, maxTicks - 1).toInt());
        _clearPendingSelection();
      });
      return;
    }

    if (_hasActiveSelection) {
      _copyActiveSelectionToTick(tick);
      return;
    }

    _setRecordStartTick(tick);
  }

  void _shiftAllNotesByOctave() {
    if (_isPlaying || !_hasNotes) return;

    final shift = _octaveShiftUpMode
        ? _PianoRollScreenState.octaveShift
        : -_PianoRollScreenState.octaveShift;
    final targetNotes = _hasActiveSelection ? _selectedNotes() : currentTrack.notes;
    if (targetNotes.isEmpty) return;

    final shiftedTargetNotes = PianoRollVoiceUseCases.transposeBatch(
      batch: targetNotes,
      semitones: shift,
      minNote: _PianoRollScreenState.minNote,
      maxNote: _PianoRollScreenState.maxNote,
    );

    final hasClampedNote = targetNotes.asMap().entries.any((entry) {
      return shiftedTargetNotes[entry.key].pitch != entry.value.pitch + shift;
    });
    if (hasClampedNote) return;

    _safeSetState(() {
      _pushHistory();

      if (_hasActiveSelection) {
        var selectedIndex = 0;
        final shiftedNotes = currentTrack.notes.map((note) {
          if (_isNoteInActiveSelection(note)) {
            final shifted = shiftedTargetNotes[selectedIndex];
            selectedIndex++;
            return shifted;
          }
          return note;
        }).toList();

        currentTrack = currentTrack.copyWith(notes: shiftedNotes);
      } else {
        currentTrack = currentTrack.copyWith(notes: shiftedTargetNotes);
      }

      _commitTrackUpdate(clearPending: true);
    });
  }

  List<MidiNote> _mergeAllAdjacentSameNotes(List<MidiNote> notes) {
    return PianoRollEditUseCases.mergeAdjacentSamePitch(notes);
  }

  void _mergeAdjacentSameNotes() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    final targetNotes = _hasActiveSelection ? _selectedNotes() : currentTrack.notes;
    if (targetNotes.isEmpty) return;

    _safeSetState(() {
      _pushHistory();

      final mergedTargetNotes = _mergeAllAdjacentSameNotes(targetNotes);

      if (_hasActiveSelection) {
        final untouchedNotes = currentTrack.notes
            .where((note) => !_isNoteInActiveSelection(note))
            .toList();

        currentTrack = currentTrack.copyWith(
          notes: [
            ...untouchedNotes,
            ...mergedTargetNotes,
          ],
        );
      } else {
        currentTrack = currentTrack.copyWith(notes: mergedTargetNotes);
      }

      _commitTrackUpdate(clearPending: true);
    });
  }

  void _splitAllNotesToSixteenth() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    final targetNotes = _hasActiveSelection ? _selectedNotes() : currentTrack.notes;
    if (targetNotes.isEmpty) return;

    _safeSetState(() {
      _pushHistory();

      final splitTargetNotes =
          PianoRollEditUseCases.splitNotesToGrid(targetNotes);

      if (_hasActiveSelection) {
        final untouchedNotes = currentTrack.notes
            .where((note) => !_isNoteInActiveSelection(note))
            .toList();

        currentTrack = currentTrack.copyWith(
          notes: [
            ...untouchedNotes,
            ...splitTargetNotes,
          ],
        );
      } else {
        currentTrack = currentTrack.copyWith(notes: splitTargetNotes);
      }

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

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      _audioService.stopPlayback();
      _safeSetState(() {
        _isPlaying = false;
      });
      return;
    }

    if (currentTrack.notes.isEmpty) return;

    await _audioService.setTrackInstrument(
        currentTrack.id, currentTrack.instrument);
    if (!mounted) return;

    _audioService.startPlayback(
      [currentTrack],
      startTick: _recordStartTick,
      onTick: () {
        _rebuild();
      },
      onFinished: () {
        if (mounted) {
          _safeSetState(() {
            _isPlaying = false;
          });
        }
      },
    );

    _safeSetState(() {
      _isPlaying = true;
    });
  }

  void _sortNotes() {
    PianoRollEditUseCases.sortNotes(currentTrack.notes);
  }

  void _setRecordStartTick(int tick) {
    _safeSetState(() {
      _recordStartTick = PianoRollPlaybackUseCases.clampStartTick(
        tick: tick,
        maxTicks: maxTicks,
      );
    });
  }

  void _handleGridHorizontalDrag(DragUpdateDetails details) {
    if (!_timeScaleController.hasClients) return;

    final maxExtent = _timeScaleController.position.maxScrollExtent;
    final newOffset =
        (_timeScaleController.offset - details.delta.dx).clamp(0.0, maxExtent);

    _timeScaleController.jumpTo(newOffset);
    _horizontalOffsetNotifier.value = newOffset.toDouble();
  }

  MidiNote? _findNoteCovering(int midiNote, int tick) {
    return PianoRollEditUseCases.findNoteCovering(
      notes: currentTrack.notes,
      pitch: midiNote,
      tick: tick,
    );
  }

  bool _canPlaceNote(int midiNote, int startTick, int durationTicks) {
    return PianoRollEditUseCases.canPlaceNote(
      notes: currentTrack.notes,
      pitch: midiNote,
      startTick: startTick,
      durationTicks: durationTicks,
      maxTicks: maxTicks,
    );
  }

  Future<void> _previewNote(int midiNote, int durationTicks) async {
    await _audioService.playNoteForTrack(currentTrack.id, midiNote);
    Future.delayed(
      Duration(
        milliseconds: PianoRollPlaybackUseCases.previewDurationMs(
          durationTicks: durationTicks,
          millisecondsPerTick: AppConstants.millisecondsPerTick,
        ),
      ),
      () {
        if (!mounted) return;
        _audioService.stopNoteForTrack(currentTrack.id, midiNote);
      },
    );
  }

  void _clearPendingSelection() {
    _editor.clearPendingSelection();
  }

  void _handleTap(int midiNote, int tick) {
    if (_isPlaying) return;

    if (_hasDraftSelection || _hasActiveSelection) {
      _safeSetState(() {
        _clearNoteSelection();
        _clearPendingSelection();
      });
      return;
    }

    _safeSetState(() {
      final existingNote = _findNoteCovering(midiNote, tick);
      if (existingNote != null) {
        _pushHistory();
        currentTrack.notes.remove(existingNote);
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

      final newNote = PianoRollEditUseCases.createNoteFromTwoTaps(
        pitch: midiNote,
        firstTick: _pendingStartTick!,
        secondTick: tick,
      );

      if (!_canPlaceNote(midiNote, newNote.startTick, newNote.durationTicks)) {
        _clearPendingSelection();
        return;
      }

      _pushHistory();
      currentTrack.notes.add(newNote);
      final durationTicks = newNote.durationTicks;
      _commitTrackUpdate();

      _previewNote(midiNote, durationTicks);
      _clearPendingSelection();
    });
  }

  void _clearAllNotes() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    if (_hasDraftSelection) {
      _safeSetState(() {
        _clearNoteSelection();
        _clearPendingSelection();
      });
      return;
    }

    if (_hasActiveSelection) {
      final selectedNotes = _selectedNotes();
      if (selectedNotes.isEmpty) return;

      _safeSetState(() {
        _pushHistory();
        currentTrack = currentTrack.copyWith(
          notes: currentTrack.notes
              .where((note) => !_isNoteInActiveSelection(note))
              .toList(),
        );
        _clearNoteSelection();
        _commitTrackUpdate(clearPending: true);
      });
      return;
    }

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
              _safeSetState(() {
                _pushHistory();
                currentTrack.notes.clear();
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
    return _labelForPitch(midiNote);
  }

  bool _isBlackKey(int midiNote) {
    if (_isDrumMode) return false;

    final noteInOctave = midiNote % 12;
    return noteInOctave == 1 ||
        noteInOctave == 3 ||
        noteInOctave == 6 ||
        noteInOctave == 8 ||
        noteInOctave == 10;
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
}
