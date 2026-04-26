import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/music/scale_autotune.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/voice_recorder_service.dart';
import '../../data/models/track_model.dart';
import '../../data/content/app_help_content.dart';
import '../../data/content/piano_roll_drum_content.dart';
import '../../data/utils/track_snapshot_utils.dart';
import '../../domain/usecases/piano_roll/piano_roll_edit_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_playback_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_voice_usecases.dart';
import '../../domain/usecases/piano_roll/piano_roll_drum_usecases.dart';

part 'piano_roll_screen_view.dart';

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

  int? _pendingStartTick;
  int? _pendingPitch;
  int _recordStartTick = 0;

  int? _selectionStartTick;
  int? _selectionEndTick;

  Timer? _nrPulseTimer;
  bool _nrPulseOn = false;
  bool _nrMetronomeEnabled = false;
  bool _octaveShiftUpMode = true;
  bool _splitMode = false;

  final List<List<MidiNote>> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
      if (!_timeScaleController.hasClients) return;
      _horizontalOffsetNotifier.value = _timeScaleController.offset;
    });

    _voiceRecorder = VoiceRecorderService();
    _voiceRecorder.initialize();
    _configureVoiceRecorderMode();
    _voiceRecorder.onNotesDetected =
        PianoRollScreenLogic(this)._onVoiceNotesDetected;

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

      PianoRollScreenLogic(this)._stopNrMetronome();

      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PianoRollScreenLogic(this)._stopNrMetronome();
    _timeScaleController.dispose();
    _verticalScrollController.dispose();
    _horizontalOffsetNotifier.dispose();
    _micBorderRotationController.dispose();

    _audioService.stopPlayback();
    _voiceRecorder.onNotesDetected = null;
    _voiceRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PianoRollScreenLogic(this).buildPianoRollScreenContent(context);
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
