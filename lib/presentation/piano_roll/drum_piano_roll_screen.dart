import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/audio_service.dart';
import '../../data/models/track_model.dart';

class DrumPianoRollScreen extends StatefulWidget {
  final Track track;
  final Function(Track) onTrackUpdated;
  final int bpm;
  final int initialStartTick;

  const DrumPianoRollScreen({
    super.key,
    required this.track,
    required this.onTrackUpdated,
    this.bpm = 120,
    this.initialStartTick = 0,
  });

  @override
  State<DrumPianoRollScreen> createState() => _DrumPianoRollScreenState();
}

class _DrumPianoRollScreenState extends State<DrumPianoRollScreen> {
  late Track currentTrack;

  final AudioService _audioService = AudioService();

  bool _isPlaying = false;

  late ScrollController _timeScaleController;
  late ScrollController _verticalScrollController;

  late int maxTicks;
  late int ticksPerBeat;
  late int beatsPerBar;
  late int ticksPerBar;

  static const int minDrumNote = 36; // C2
  static const int maxDrumNote = 60; // C4

  static const double _rowHeight = 32.0;
  static double get _leftLabelWidth => AppConstants.keyAreaWidth + 25;

  int? _pendingStartTick;
  int? _pendingPitch;
  int _recordStartTick = 0;

  final List<List<MidiNote>> _history = [];

  static const Map<int, String> _drumLabels = {
    60: 'Bell / FX',
    59: 'Ride 2',
    58: 'Vibraslap',
    57: 'Crash 2',
    56: 'Cowbell',
    55: 'Splash',
    54: 'Tambourine',
    53: 'Ride Bell',
    52: 'Chinese',
    51: 'Ride 1',
    50: 'Tom High',
    49: 'Crash 1',
    48: 'Tom High Mid',
    47: 'Tom High',
    46: 'Hi-Hat Open',
    45: 'Tom Mid',
    44: 'Hi-Hat Pedal',
    43: 'Tom Low',
    42: 'Hi-Hat Closed',
    41: 'Tom Floor',
    40: 'Snare',
    39: 'Clap',
    38: 'Snare Alt',
    37: 'Rim',
    36: 'Kick',
  };

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
      }

      if (_verticalScrollController.hasClients) {
        _scrollToDrumNotes();
      }

      if (mounted) {
        setState(() {});
      }
    });

    _setupTrackInstrument();
  }

  void _setupTrackInstrument() {
    _audioService.setTrackInstrument(currentTrack.id, 'Ударные');
  }

  void _scrollToDrumNotes() {
    if (!_verticalScrollController.hasClients) return;
    if (currentTrack.notes.isEmpty) return;

    int highestPitch = currentTrack.notes.first.pitch;
    int lowestPitch = currentTrack.notes.first.pitch;

    for (final note in currentTrack.notes) {
      if (note.pitch > highestPitch) highestPitch = note.pitch;
      if (note.pitch < lowestPitch) lowestPitch = note.pitch;
    }

    final centerPitch = ((highestPitch + lowestPitch) / 2).round();
    final targetIndex =
        (maxDrumNote - centerPitch).clamp(0, maxDrumNote - minDrumNote);

    final viewportHeight = _verticalScrollController.position.viewportDimension;
    final rawOffset =
        (targetIndex * _rowHeight) - (viewportHeight / 2) + (_rowHeight / 2);

    final clampedOffset = rawOffset.clamp(
      0.0,
      _verticalScrollController.position.maxScrollExtent,
    );

    _verticalScrollController.jumpTo(clampedOffset);
  }

  @override
  void dispose() {
    _timeScaleController.dispose();
    _verticalScrollController.dispose();
    _audioService.stopPlayback();
    super.dispose();
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

  bool get _hasNotes => currentTrack.notes.isNotEmpty;
  bool get _canUndo => _history.isNotEmpty && !_isPlaying;

  void _undoLastAction() {
    if (!_canUndo) return;

    final previous = _history.removeLast();

    setState(() {
      currentTrack = currentTrack.copyWith(notes: _cloneNotes(previous));
      _clearPendingSelection();
      _commitTrackUpdate();
    });
  }

  void _commitTrackUpdate({bool clearPending = false}) {
    _sortNotes();
    if (clearPending) {
      _clearPendingSelection();
    }
    widget.onTrackUpdated(currentTrack);
  }

  void _sortNotes() {
    currentTrack.notes.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
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

    _audioService.setTrackInstrument(currentTrack.id, 'Ударные');

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

  void _setRecordStartTick(int tick) {
    setState(() {
      _recordStartTick = tick.clamp(0, maxTicks - 1);
    });
  }

  void _handleGridHorizontalDrag(DragUpdateDetails details) {
    if (!_timeScaleController.hasClients) return;

    final maxExtent = _timeScaleController.position.maxScrollExtent;
    final newOffset =
        (_timeScaleController.offset - details.delta.dx).clamp(0.0, maxExtent);

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

  bool _isNotePresent(int midiNote, int tick) {
    return _findNoteCovering(midiNote, tick) != null;
  }

  bool _isPendingCell(int midiNote, int tick) {
    return _pendingPitch == midiNote && _pendingStartTick == tick;
  }

  bool _isNoteStart(int midiNote, int tick) {
    final note = _findNoteCovering(midiNote, tick);
    return note != null && note.startTick == tick;
  }

  bool _isNoteEnd(int midiNote, int tick) {
    final note = _findNoteCovering(midiNote, tick);
    return note != null && (note.startTick + note.durationTicks - 1) == tick;
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
          'Очистить все удары',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Удалить все ноты барабанов в этой дорожке?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
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

  void _showDrumHelpDialog() {
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
        title: const Text(
          'Как пользоваться барабанами',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DrumHelpLine(
                title: 'Постановка удара',
                text:
                    'Первое нажатие задаёт начало ноты, второе — её длину.',
              ),
              SizedBox(height: 10),
              _DrumHelpLine(
                title: 'Удаление удара',
                text: 'Нажми по уже существующей ноте, чтобы удалить её.',
              ),
              SizedBox(height: 10),
              _DrumHelpLine(
                title: 'Старт воспроизведения',
                text:
                    'Нажимай на верхнюю тактовую ленту, чтобы выбрать, с какого места начать проигрывание.',
              ),
              SizedBox(height: 10),
              _DrumHelpLine(
                title: 'Горизонтальная навигация',
                text:
                    'Свайпай по верхней тактовой ленте или по сетке, чтобы двигаться по проекту.',
              ),
              SizedBox(height: 10),
              _DrumHelpLine(
                title: 'Подписи ударных',
                text:
                    'Слева показаны названия ударных от Kick до Crash, Ride и FX.',
              ),
              SizedBox(height: 10),
              _DrumHelpLine(
                title: 'Play',
                text:
                    'Короткое нажатие запускает обычное воспроизведение. Долгое нажатие можно использовать для зацикливания.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
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

  Widget _buildInfoButton() {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: _showDrumHelpDialog,
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

  String _drumLabel(int midiNote) {
    return _drumLabels[midiNote] ?? 'Удар';
  }

  @override
  Widget build(BuildContext context) {
    final playheadTick = _audioService.currentTick;
    final horizontalOffset =
        _timeScaleController.hasClients ? _timeScaleController.offset : 0.0;
    final notesEnabled = !_isPlaying;

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
                        const SizedBox(width: 8),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: _leftLabelWidth + 2,
                        height: 50,
                        child: Center(
                          child: Text(
                            'DRUMS',
                            style: TextStyle(
                              color: currentTrack.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
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
                            itemCount: maxDrumNote - minDrumNote + 1,
                            itemBuilder: (context, rowIndex) {
                              final midiNote = maxDrumNote - rowIndex;

                              return SizedBox(
                                height: _rowHeight,
                                child: Row(
                                  children: [
                                    Container(
                                      width: _leftLabelWidth,
                                      height: _rowHeight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade800,
                                          ),
                                          right: BorderSide(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        color: Colors.grey[850],
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _drumLabel(midiNote),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: currentTrack.color,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: _rowHeight,
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
                                                height: _rowHeight,
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
                                                          _isNoteStart(
                                                        midiNote,
                                                        tickIndex,
                                                      );
                                                      final isEnd = _isNoteEnd(
                                                        midiNote,
                                                        tickIndex,
                                                      );

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
                                                                : isNotePresent
                                                                    ? currentTrack
                                                                        .color
                                                                        .withValues(
                                                                            alpha:
                                                                                0.82)
                                                                    : Colors
                                                                        .transparent,
                                                            borderRadius:
                                                                isNotePresent
                                                                    ? BorderRadius
                                                                        .only(
                                                                        topLeft: isStart
                                                                            ? const Radius.circular(7)
                                                                            : Radius.zero,
                                                                        bottomLeft: isStart
                                                                            ? const Radius.circular(7)
                                                                            : Radius.zero,
                                                                        topRight: isEnd
                                                                            ? const Radius.circular(7)
                                                                            : Radius.zero,
                                                                        bottomRight: isEnd
                                                                            ? const Radius.circular(7)
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
                                            height: _rowHeight,
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
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppConstants.horizontalPadding,
            right: AppConstants.horizontalPadding,
            bottom: 20,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoundButton(
                    icon: Icons.undo,
                    onPressed: _canUndo ? _undoLastAction : null,
                    color: currentTrack.color,
                  ),
                  const SizedBox(width: 40),
                  _buildRoundButton(
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    onPressed: _togglePlayback,
                    color: currentTrack.color,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrumHelpLine extends StatelessWidget {
  final String title;
  final String text;

  const _DrumHelpLine({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}