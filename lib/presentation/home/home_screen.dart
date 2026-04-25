import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../widgets/instrument_picker_dialog.dart';
import '../../core/navigation/fade_page_route.dart';
import '../../core/styles/project_style.dart';
import '../../core/styles/project_styles.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/models/track_model.dart';
import '../../data/content/app_help_content.dart';
import '../../data/repositories/track_repository.dart';
import '../../data/utils/track_snapshot_utils.dart';
import '../../domain/services/bar_note_service.dart';
import '../pages/launch_screen.dart';
import '../piano_roll/piano_roll_screen.dart';
import 'home_controller.dart';
import '../widgets/track_row_widget.dart';

part 'home_screen_view.dart';

class HomeScreen extends StatefulWidget {
  final bool loadSavedProject;
  final ProjectStyleType initialStyleType;

  const HomeScreen({
    super.key,
    this.loadSavedProject = true,
    this.initialStyleType = ProjectStyleType.standard,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late HomeController _controller;
  late TrackRepository _repository;

  PatternSegment? _selectedSegment;
  String? _selectedTrackId;
  Timer? _segmentClearTimer;

  Timer? _titlePulseTimer;
  bool _titlePulseOn = false;

  final List<List<Track>> _history = [];
  final List<List<Track>> _redoHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = TrackRepository();
    _controller = HomeController(_repository);
    _controller.addListener(_controllerListener);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _calculateBarWidth();

      if (widget.loadSavedProject) {
        final loaded = await _controller.loadProject(
          styleType: widget.initialStyleType,
        );
        if (!loaded) {
          _controller.createNewProject(styleType: widget.initialStyleType);
        }
      } else {
        _controller.createNewProject(styleType: widget.initialStyleType);
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  void _controllerListener() {
    if (!mounted) return;

    if (_controller.isPlaying) {
      _startTitlePulse();
    } else {
      _stopTitlePulse();
    }

    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateBarWidth();
  }

  @override
  void dispose() {
    _segmentClearTimer?.cancel();
    _titlePulseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.stopPlayback();
      _stopTitlePulse();
    }
  }

  bool get _canUndo => _history.isNotEmpty && !_controller.isPlaying;
  bool get _canRedo => _redoHistory.isNotEmpty && !_controller.isPlaying;

  void _startTitlePulse() {
    if (_titlePulseTimer != null) return;

    _titlePulseOn = true;
    final beatMs = (60000 / AppConstants.bpm).round();

    _titlePulseTimer = Timer.periodic(Duration(milliseconds: beatMs), (_) {
      if (!mounted || !_controller.isPlaying) {
        _stopTitlePulse();
        return;
      }

      setState(() {
        _titlePulseOn = !_titlePulseOn;
      });
    });
  }

  void _stopTitlePulse() {
    _titlePulseTimer?.cancel();
    _titlePulseTimer = null;
    _titlePulseOn = false;
  }

  void _calculateBarWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    AppConstants.updateBarWidthForScreen(screenWidth);
  }

  Map<String, int> _getNoteRange(Track track) {
    return BarNoteService.noteRange(track).toMap();
  }

  @override
  Widget build(BuildContext context) =>
      HomeScreenLogic(this).buildHomeScreenContent(context);
}

class _HomeHelpLine extends StatelessWidget {
  final String title;
  final String text;

  const _HomeHelpLine({
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
