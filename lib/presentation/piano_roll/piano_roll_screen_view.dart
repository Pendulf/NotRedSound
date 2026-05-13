// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, unused_element, avoid_unnecessary_containers, use_build_context_synchronously
part of 'piano_roll_screen.dart';

extension PianoRollScreenLogic on _PianoRollScreenState {
  List<MidiNote> _cloneNotes(List<MidiNote> source) {
    return TrackSnapshotUtils.cloneNotes(source);
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

  void _undoLastAction() {
    if (!_canUndo) return;

    final previous = _history.removeLast();

    setState(() {
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

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      await _voiceRecorder.stopRecording();

      _micBorderRotationController.stop();

      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
      });
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
      minNote: _PianoRollScreenState.minNote,
      maxNote: _PianoRollScreenState.maxNote,
    );
  }

  bool _isNoteStart(int midiNote, int tick) {
    final note = _findNoteCovering(midiNote, tick);
    return note != null && note.startTick == tick;
  }

  bool _isNoteEnd(int midiNote, int tick) {
    final note = _findNoteCovering(midiNote, tick);
    return note != null && (note.startTick + note.durationTicks - 1) == tick;
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
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Color.fromRGBO(224, 67, 54, 1),
                                Color.fromRGBO(33, 130, 243, 1),
                                Color.fromRGBO(156, 39, 156, 1),
                                Color.fromRGBO(224, 67, 54, 1),
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

  void _showPianoRollHelpDialog() {
    final helpTitle = _isDrumMode
        ? AppHelpContent.drumRollTitle
        : AppHelpContent.pianoRollTitle;
    final helpItems =
        _isDrumMode ? AppHelpContent.drumRoll : AppHelpContent.pianoRoll;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: currentTrack.color,
            width: 2,
          ),
        ),
        title: Text(
          helpTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < helpItems.length; i++) ...[
                _PianoHelpLine(
                  title: helpItems[i].title,
                  text: helpItems[i].text,
                ),
                if (i != helpItems.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppHelpContent.okButton),
          ),
        ],
      ),
    );
  }

  void _onVoiceNotesDetected(List<VoiceNote> notes) {
    if (_isDrumMode || notes.isEmpty) return;

    setState(() {
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
    setState(() {
      _octaveShiftUpMode = !_octaveShiftUpMode;
    });
  }

  void _toggleMergeSplitMode() {
    setState(() {
      _splitMode = !_splitMode;
    });
  }

  int? get _selectionRangeStartTick {
    if (_selectionStartTick == null || _selectionEndTick == null) return null;
    return math.min(_selectionStartTick!, _selectionEndTick!)
        .clamp(0, maxTicks)
        .toInt();
  }

  int? get _selectionRangeEndTick {
    if (_selectionStartTick == null || _selectionEndTick == null) return null;
    return (math.max(_selectionStartTick!, _selectionEndTick!) + 1)
        .clamp(0, maxTicks)
        .toInt();
  }

  bool get _hasDraftSelection =>
      _selectionStartTick != null && _selectionEndTick == null;

  bool get _hasActiveSelection =>
      _selectionStartTick != null && _selectionEndTick != null;

  bool _isTickInDraftSelection(int tick) {
    return _hasDraftSelection && _selectionStartTick == tick;
  }

  bool _isTickInActiveSelection(int tick) {
    final rangeStart = _selectionRangeStartTick;
    final rangeEnd = _selectionRangeEndTick;
    if (rangeStart == null || rangeEnd == null) return false;
    return tick >= rangeStart && tick < rangeEnd;
  }

  bool _isBarStartInSelection(int barStartTick) {
    return _isTickInDraftSelection(barStartTick) ||
        _isTickInActiveSelection(barStartTick);
  }

  bool _isNoteInActiveSelection(MidiNote note) {
    final rangeStart = _selectionRangeStartTick;
    final rangeEnd = _selectionRangeEndTick;
    if (rangeStart == null || rangeEnd == null) return false;
    return note.intersectsRange(rangeStart, rangeEnd);
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

    setState(() {
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
    _selectionStartTick = null;
    _selectionEndTick = null;
  }

  void _beginNoteSelectionFromTick(int tick) {
    if (_isPlaying) return;

    setState(() {
      _selectionStartTick = tick.clamp(0, maxTicks - 1).toInt();
      _selectionEndTick = null;
      _clearPendingSelection();
    });
  }

  void _handleTimeScaleTap(int tick) {
    if (_isPlaying) return;

    if (_hasDraftSelection) {
      setState(() {
        _selectionEndTick = tick.clamp(0, maxTicks - 1).toInt();
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

    setState(() {
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

    setState(() {
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

  List<MidiNote> _splitNoteToSixteenth(MidiNote note) {
    return PianoRollEditUseCases.splitNotesToGrid([note]);
  }

  void _splitAllNotesToSixteenth() {
    if (_isPlaying || currentTrack.notes.isEmpty) return;

    final targetNotes = _hasActiveSelection ? _selectedNotes() : currentTrack.notes;
    if (targetNotes.isEmpty) return;

    setState(() {
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
      setState(() {
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
    PianoRollEditUseCases.sortNotes(currentTrack.notes);
  }

  void _setRecordStartTick(int tick) {
    setState(() {
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
    _pendingStartTick = null;
    _pendingPitch = null;
  }

  void _handleTap(int midiNote, int tick) {
    if (_isPlaying) return;

    if (_hasDraftSelection || _hasActiveSelection) {
      setState(() {
        _clearNoteSelection();
        _clearPendingSelection();
      });
      return;
    }

    setState(() {
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
      setState(() {
        _clearNoteSelection();
        _clearPendingSelection();
      });
      return;
    }

    if (_hasActiveSelection) {
      final selectedNotes = _selectedNotes();
      if (selectedNotes.isEmpty) return;

      setState(() {
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
              setState(() {
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
    final ringThickness = _isRecordingVoice ? 5.3 : 3.5;

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
                    gradient: const SweepGradient(
                      colors: [
                        Color.fromRGBO(224, 67, 54, 1),
                        Color.fromRGBO(33, 130, 243, 1),
                        Color.fromRGBO(156, 39, 156, 1),
                        Color.fromRGBO(224, 67, 54, 1),
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
                      size: _isRecordingVoice ? 30 : 26,
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
                        color: Colors.red
                            .withValues(alpha: _nrPulseOn ? 0.30 : 0.18),
                        blurRadius: _nrPulseOn ? 26 : 16,
                        spreadRadius: _nrPulseOn ? 4 : 1,
                      ),
                      BoxShadow(
                        color: Colors.purple
                            .withValues(alpha: _nrPulseOn ? 0.28 : 0.16),
                        blurRadius: _nrPulseOn ? 34 : 20,
                        spreadRadius: _nrPulseOn ? 5 : 2,
                      ),
                      BoxShadow(
                        color: Colors.blue
                            .withValues(alpha: _nrPulseOn ? 0.24 : 0.14),
                        blurRadius: _nrPulseOn ? 42 : 24,
                        spreadRadius: _nrPulseOn ? 6 : 2,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                'NRS',
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
                  'NRS',
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
    final innerColor = currentTrack.color;

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

  Widget _buildInfoButton() {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: _showPianoRollHelpDialog,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: const Icon(
          Icons.info_outline,
          color: Color.fromARGB(255, 186, 186, 186),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final notesEnabled = _hasNotes && !_isRecordingVoice;

    return SizedBox(
      height: 60,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final sideGap = compact ? 12.0 : 20.0;
          final centerGap = compact
              ? (constraints.maxWidth * 0.18).clamp(48.0, 74.0).toDouble()
              : 98.0;

          final rowChildren = _isDrumMode
              ? <Widget>[
                  _buildRoundButton(
                    icon: Icons.undo,
                    onPressed: _canUndo ? _undoLastAction : null,
                    color: currentTrack.color,
                  ),
                  SizedBox(width: centerGap),
                  _buildRoundButton(
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    onPressed: notesEnabled ? _togglePlayback : null,
                    color: currentTrack.color,
                  ),
                ]
              : <Widget>[
                  _buildRoundButton(
                    icon: _splitMode ? Icons.call_split : Icons.merge_type,
                    onPressed: notesEnabled ? _handleMergeSplitAction : null,
                    onLongPress: notesEnabled ? _toggleMergeSplitMode : null,
                    color: currentTrack.color,
                  ),
                  SizedBox(width: sideGap),
                  _buildRoundButton(
                    icon: Icons.undo,
                    onPressed: _canUndo ? _undoLastAction : null,
                    color: currentTrack.color,
                  ),
                  SizedBox(width: centerGap),
                  _buildRoundButton(
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    onPressed: notesEnabled ? _togglePlayback : null,
                    color: currentTrack.color,
                  ),
                  SizedBox(width: sideGap),
                  _buildRoundButton(
                    icon: _octaveShiftUpMode
                        ? Icons.keyboard_double_arrow_up
                        : Icons.keyboard_double_arrow_down,
                    onPressed: notesEnabled ? _shiftAllNotesByOctave : null,
                    onLongPress: notesEnabled ? _toggleOctaveShiftMode : null,
                    color: currentTrack.color,
                  ),
                ];

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 50,
                      color: currentTrack.color.withAlpha(50),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: rowChildren,
              ),
              if (!_isDrumMode)
                Positioned(
                  child: _buildMicButton(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget buildPianoRollScreenContent(BuildContext context) {
    final playheadTick = _audioService.currentTick;
    final notesEnabled = _hasNotes && !_isRecordingVoice;
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final horizontalPadding =
        AppConstants.responsiveHorizontalPadding(screenWidth);
    final keyAreaWidth = AppConstants.responsiveKeyAreaWidth(screenWidth);
    final bottomInset = media.padding.bottom;
    final nrsTop = media.padding.top + 58 + 16 + 4;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppConstants.background,
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
                left: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
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
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
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
                        _buildInfoButton(),
                        if (!_isDrumMode) ...[
                          const SizedBox(width: 8),
                          _buildAutotuneButton(),
                        ],
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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: keyAreaWidth - 7,
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
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.horizontal,
                            controller: _timeScaleController,
                            physics: const ClampingScrollPhysics(),
                            itemCount: maxTicks,
                            itemBuilder: (context, index) {
                              final isBarStart = index % ticksPerBar == 0;
                              final isPlayhead =
                                  _isPlaying && playheadTick == index;
                              final isRecordStart =
                                  !_isPlaying && _recordStartTick == index;
                              final isDraftSelection =
                                  _isTickInDraftSelection(index);
                              final isActiveSelection =
                                  _isTickInActiveSelection(index);
                              final isBarNumberInSelection =
                                  _isBarStartInSelection(index);
                              final Color cellColor;
                              if (isDraftSelection) {
                                cellColor = Colors.green.withValues(alpha: 0.12);
                              } else if (isActiveSelection) {
                                cellColor = Colors.green.withValues(alpha: 0.26);
                              } else if (isPlayhead || isRecordStart) {
                                cellColor = Colors.amber.withValues(alpha: 0.18);
                              } else {
                                cellColor = Colors.transparent;
                              }

                              return GestureDetector(
                                onTap: () => _handleTimeScaleTap(index),
                                onLongPress: () => _beginNoteSelectionFromTick(index),
                                child: Container(
                                  width: AppConstants.noteCellWidth,
                                  decoration: BoxDecoration(
                                    color: cellColor,
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
                                            style: TextStyle(
                                              color: isBarNumberInSelection
                                                  ? Colors.greenAccent
                                                  : Colors.amber,
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
                    child: ValueListenableBuilder<double>(
                      valueListenable: _horizontalOffsetNotifier,
                      builder: (context, horizontalOffset, _) {
                        return GestureDetector(
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
                            itemCount: _visibleMidiNotes.length,
                            itemBuilder: (context, noteIndex) {
                              final midiNote = _visibleMidiNotes[noteIndex];
                              final isBlackKey = _isBlackKey(midiNote);
                              final octaveName = _getOctaveName(midiNote);
                              final notesForPitch = currentTrack.notes
                                  .where((note) => note.pitch == midiNote)
                                  .toList(growable: false);

                              return SizedBox(
                                height: _rollRowHeight,
                                child: Row(
                                  children: [
                                    Container(
                                      width: keyAreaWidth,
                                      height: _rollRowHeight,
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
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 7),
                                          child: octaveName.isNotEmpty
                                              ? Text(
                                                  octaveName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: currentTrack.color,
                                                    fontSize:
                                                        _isDrumMode ? 12 : 14,
                                                    height:
                                                        _isDrumMode ? 1.0 : 1.0,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: _rollRowHeight,
                                      color: Colors.amber,
                                    ),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final viewportWidth =
                                              constraints.maxWidth;
                                          final firstVisibleTick =
                                              (horizontalOffset /
                                                      AppConstants
                                                          .noteCellWidth)
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
                                            final existingNote =
                                                PianoRollEditUseCases
                                                    .findNoteCovering(
                                              notes: notesForPitch,
                                              pitch: midiNote,
                                              tick: tickIndex,
                                            );
                                            final isNotePresent =
                                                existingNote != null;
                                            final isSelectedNoteCell =
                                                existingNote != null &&
                                                    _isNoteInActiveSelection(
                                                        existingNote) &&
                                                    _isTickInActiveSelection(
                                                        tickIndex);
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
                                                height: _rollRowHeight,
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: () => _handleTap(
                                                    midiNote,
                                                    tickIndex,
                                                  ),
                                                  child: Builder(
                                                    builder: (_) {
                                                      final isStart =
                                                          existingNote != null &&
                                                              existingNote
                                                                      .startTick ==
                                                                  tickIndex;
                                                      final isEnd =
                                                          existingNote != null &&
                                                              existingNote.endTick -
                                                                      1 ==
                                                                  tickIndex;

                                                      const double startRadius =
                                                          7.0;
                                                      const double endRadius =
                                                          7.0;

                                                      return Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border(
                                                            right: BorderSide(
                                                              color:
                                                                  _getLineColor(
                                                                tickIndex + 1,
                                                              ),
                                                              width:
                                                                  _getLineWidth(
                                                                tickIndex + 1,
                                                              ),
                                                            ),
                                                            bottom: BorderSide(
                                                              color: Colors.grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isPending
                                                                ? Colors
                                                                    .lightGreen
                                                                    .withValues(
                                                                        alpha:
                                                                            0.55)
                                                                : isSelectedNoteCell
                                                                    ? Colors
                                                                        .green
                                                                        .withValues(
                                                                            alpha:
                                                                                0.82)
                                                                    : isNotePresent
                                                                        ? currentTrack
                                                                            .color
                                                                            .withValues(
                                                                                alpha:
                                                                                    0.78)
                                                                        : Colors
                                                                            .transparent,
                                                            borderRadius:
                                                                isNotePresent
                                                                    ? BorderRadius
                                                                        .only(
                                                                        topLeft: isStart
                                                                            ? const Radius.circular(startRadius)
                                                                            : Radius.zero,
                                                                        bottomLeft: isStart
                                                                            ? const Radius.circular(startRadius)
                                                                            : Radius.zero,
                                                                        topRight: isEnd
                                                                            ? const Radius.circular(endRadius)
                                                                            : Radius.zero,
                                                                        bottomRight: isEnd
                                                                            ? const Radius.circular(endRadius)
                                                                            : Radius.zero,
                                                                      )
                                                                    : BorderRadius
                                                                        .zero,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return SizedBox(
                                            width: viewportWidth,
                                            height: _rollRowHeight,
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
                    );
                  },
                ),
              ),
                  SizedBox(height: 96 + bottomInset),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                color: _isRecordingVoice
                    ? Colors.black.withValues(alpha: 0.33)
                    : Colors.transparent,
              ),
            ),
          ),
          Positioned(
            left: horizontalPadding,
            top: nrsTop,
            width: keyAreaWidth - 7,
            height: 50,
            child: IgnorePointer(
              ignoring: !_isRecordingVoice,
              child: Center(
                child: _buildOutlinedGradientNr(),
              ),
            ),
          ),
          Positioned(
            left: horizontalPadding,
            right: horizontalPadding,
            bottom: 20 + bottomInset,
            child: _buildBottomToolbar(),
          ),
        ],
      ),
    );
  }
}
