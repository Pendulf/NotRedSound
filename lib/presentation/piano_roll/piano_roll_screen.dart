import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../data/content/app_help_content.dart';
import '../../data/content/piano_roll_drum_content.dart';
import '../../domain/entities/track_model.dart';
import '../../domain/services/scale_autotune.dart';
import '../../domain/usecases/piano_roll/piano_roll_drum_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_edit_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_playback_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_voice_usecases.dart';
import '../../infrastructure/audio/audio_service.dart';
import '../../infrastructure/voice/voice_recorder_service.dart';

part 'piano_roll_controller.dart';

class PianoRollScreen extends StatefulWidget {
  final Track track;
  final Function(Track) onTrackUpdated;
  final int bpm;
  final int initialStartTick;

  const PianoRollScreen({
    super.key,
    required this.track,
    required this.onTrackUpdated,
    this.bpm = 120,
    this.initialStartTick = 0,
  });

  @override
  State<PianoRollScreen> createState() => _PianoRollScreenState();
}



class _PianoHelpLine extends StatelessWidget {
  final String title;
  final String text;

  const _PianoHelpLine({
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

extension _PianoRollScreenLogic on _PianoRollScreenState {
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
                    _rebuild();
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
