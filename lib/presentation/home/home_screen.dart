import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/navigation/fade_page_route.dart';
import '../../core/styles/project_style.dart';
import '../../core/styles/project_styles.dart';
import '../../data/content/app_help_content.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../../domain/entities/pattern_segment.dart';
import '../../domain/entities/track_model.dart';
import '../../domain/services/bar_note_service.dart';
import '../../domain/usecases/home/home_pattern_usecases.dart';
import '../../domain/usecases/home/home_project_usecases.dart';
import '../../domain/usecases/home/home_track_usecases.dart';
import '../../domain/utils/track_snapshot_utils.dart';
import '../../infrastructure/audio/audio_service.dart';
import '../../infrastructure/export/export_midi_usecase_impl.dart';
import '../common/widgets/instrument_picker_dialog.dart';
import '../common/widgets/track_row_widget.dart';
import '../launch/launch_screen.dart';
import '../piano_roll/piano_roll_screen.dart';

part 'home_controller.dart';

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

extension _HomeScreenLogic on _HomeScreenState {
  void _showHomeHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppConstants.styleColor,
            width: 1.2,
          ),
        ),
        title: const Text(
          AppHelpContent.homeTitle,
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < AppHelpContent.home.length; i++) ...[
                _HomeHelpLine(
                  title: AppHelpContent.home[i].title,
                  text: AppHelpContent.home[i].text,
                ),
                if (i != AppHelpContent.home.length - 1)
                  const SizedBox(height: 10),
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

  Widget _buildInfoButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showHomeHelpDialog,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            Icons.info_outline,
            color: Colors.white.withValues(alpha: 0.65),
            size: 24,
          ),
        ),
      ),
    );
  }

  void _showProjectPopup() {
    showDialog(
      context: context,
      builder: (context) {
        int tempBpm = AppConstants.bpm;
        int tempBars = AppConstants.totalBars;
        int tempBeatsPerBar = AppConstants.beatsPerBar;
        int tempTicksPerBeat = AppConstants.ticksPerBeat;
        ProjectStyleType tempStyleType = AppConstants.currentStyleType;

        DateTime? lastTapTime;
        final List<int> tapIntervalsMs = [];

        void handleTapTempo(void Function(void Function()) setLocalState) {
          final now = DateTime.now();

          if (lastTapTime == null) {
            lastTapTime = now;
            return;
          }

          final diff = now.difference(lastTapTime!).inMilliseconds;
          lastTapTime = now;

          if (diff < 120 || diff > 2000) {
            tapIntervalsMs.clear();
            return;
          }

          tapIntervalsMs.add(diff);

          if (tapIntervalsMs.length > 6) {
            tapIntervalsMs.removeAt(0);
          }

          final averageMs =
              tapIntervalsMs.reduce((a, b) => a + b) / tapIntervalsMs.length;

          final calculatedBpm =
              _roundToNearestFive((60000 / averageMs).round());

          setLocalState(() {
            tempBpm = calculatedBpm;
          });
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            final currentStyle = ProjectStyles.byType(tempStyleType);

            return AlertDialog(
              backgroundColor: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: currentStyle.primaryColor,
                  width: 1.2,
                ),
              ),
              title: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(context);
                  _openLaunchScreen();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Проект',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Стиль: ${currentStyle.displayName}',
                        style: TextStyle(
                          color: currentStyle.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Темп (BPM)',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBpm = (tempBpm - 5).clamp(40, 240);
                            });
                          },
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: () => handleTapTempo(setLocalState),
                              child: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '$tempBpm',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBpm = (tempBpm + 5).clamp(40, 240);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Количество тактов',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBars = (tempBars - 1).clamp(1, 100);
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            '$tempBars',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            setLocalState(() {
                              tempBars = (tempBars + 1).clamp(1, 100);
                            });
                          },
                        ),
                      ],
                    ),
                    const Text(
                      'Размер такта',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setLocalState(() {
                                tempBeatsPerBar = 3;
                                tempTicksPerBeat = 3;
                              });
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: tempTicksPerBeat == 3
                                  ? currentStyle.primaryColor
                                  : Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('3/4'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setLocalState(() {
                                tempBeatsPerBar = 4;
                                tempTicksPerBeat = 4;
                              });
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: tempTicksPerBeat == 4
                                  ? currentStyle.primaryColor
                                  : Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('4/4'),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.save, color: Colors.green),
                      title: const Text(
                        'Сохранить проект',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        await _controller.switchProjectStyle(tempStyleType);
                        AppConstants.updateBpm(tempBpm);
                        AppConstants.updateTotalBars(tempBars);
                        AppConstants.updateTimeSignature(
                          newBeatsPerBar: tempBeatsPerBar,
                          newTicksPerBeat: tempTicksPerBeat,
                        );
                        _calculateBarWidth();
                        if (!mounted) return;
                        Navigator.pop(context);
                        _safeSetHomeState(() {});
                        _saveProject();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.share, color: Colors.blue),
                      title: const Text(
                        'Отправить проект',
                        style: TextStyle(color: Colors.white),
                      ),
                      
                      onTap: () async {
                        await _controller.switchProjectStyle(tempStyleType);
                        AppConstants.updateBpm(tempBpm);
                        AppConstants.updateTotalBars(tempBars);
                        AppConstants.updateTimeSignature(
                          newBeatsPerBar: tempBeatsPerBar,
                          newTicksPerBeat: tempTicksPerBeat,
                        );
                        _calculateBarWidth();
                        if (!mounted) return;
                        Navigator.pop(context);
                        _safeSetHomeState(() {});

                        _exportToMidi(share: true);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Очистить проект',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteProject();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _controller.switchProjectStyle(tempStyleType);
                    AppConstants.updateBpm(tempBpm);
                    AppConstants.updateTotalBars(tempBars);
                    AppConstants.updateTimeSignature(
                      newBeatsPerBar: tempBeatsPerBar,
                      newTicksPerBeat: tempTicksPerBeat,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    _calculateBarWidth();
                    _safeSetHomeState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.styleColor,
                  ),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.red, width: 1.2),
        ),
        title: const Text(
          'Очистить текущий проект',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Все ноты в текущих дорожках будут удалены, но сами дорожки сохранятся. Продолжить?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCurrentProject();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }

  void _showInstrumentPickerForTrack(Track track) {
    showInstrumentPickerDialog(
      context,
      track,
      (instrument) {
        _pushHistory();
        _controller.updateTrackInstrument(track.id, instrument);
        _safeSetHomeState(() {});
      },
    );
  }

  void _showSnackBar(
    String message,
    Color color, {
    Duration duration = const Duration(seconds: 1),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  Widget _buildPlayheadHeaderOverlay() {
  if (!_controller.isPlaying) {
    return const SizedBox.shrink();
  }

  return AnimatedBuilder(
    animation: _controller.horizontalScrollController,
    builder: (context, _) {
      final tickWidth = AppConstants.barWidth / AppConstants.ticksPerBar;
      final offset = _controller.horizontalScrollController.hasClients
          ? _controller.horizontalScrollController.offset
          : 0.0;

      final playheadX = (_controller.currentTick * tickWidth) - offset;

      return Positioned(
        left: playheadX,
        top: 10,
        bottom: 10,
        child: IgnorePointer(
          child: Container(
            width: 3,
            color: Colors.amber,
          ),
        ),
      );
    },
  );
}

  Widget _buildAnimatedTitle() {
    final pulseDuration = Duration(
      milliseconds: (60000 / AppConstants.bpm / 2).round(),
    );

    return SizedBox(
      height: 40,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidth = constraints.maxWidth.clamp(96.0, 220.0).toDouble();

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: AnimatedScale(
                  scale: _controller.isPlaying
                      ? (_titlePulseOn ? 1.18 : 1.0)
                      : 1.0,
                  duration: pulseDuration,
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    opacity: _controller.isPlaying
                        ? (_titlePulseOn ? 1.0 : 0.72)
                        : 0.82,
                    duration: pulseDuration,
                    child: Container(
                      width: titleWidth,
                      height: 30,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(
                              alpha: _controller.isPlaying
                                  ? (_titlePulseOn ? 0.28 : 0.16)
                                  : 0.16,
                            ),
                            blurRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 24 : 16)
                                : 16,
                            spreadRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 3 : 1)
                                : 1,
                          ),
                          BoxShadow(
                            color: AppConstants.styleColor.withValues(
                              alpha: _controller.isPlaying
                                  ? (_titlePulseOn ? 0.24 : 0.14)
                                  : 0.14,
                            ),
                            blurRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 30 : 20)
                                : 20,
                            spreadRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 4 : 1)
                                : 1,
                          ),
                          BoxShadow(
                            color: Colors.blue.withValues(
                              alpha: _controller.isPlaying
                                  ? (_titlePulseOn ? 0.20 : 0.12)
                                  : 0.12,
                            ),
                            blurRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 36 : 24)
                                : 24,
                            spreadRadius: _controller.isPlaying
                                ? (_titlePulseOn ? 5 : 2)
                                : 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: AppConstants.brandGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'NotRedSound',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget buildHomeScreenContent(BuildContext context) {
    final hasTracks = _controller.tracks.isNotEmpty;
    final selectedBar = _controller.isPlaying
        ? -1
        : _controller.playbackStartBar.clamp(0, AppConstants.maxBars - 1);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        AppConstants.responsiveHorizontalPadding(screenWidth);
    final addButtonWidth = (screenWidth * 0.45).clamp(150.0, 200.0).toDouble();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
            ),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 8),
                Container(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color.fromARGB(255, 123, 36, 29)
                            .withValues(alpha: 0.60),
                        const Color.fromARGB(255, 109, 29, 123)
                            .withValues(alpha: 0.60),
                        const Color.fromARGB(255, 19, 112, 175)
                            .withValues(alpha: 0.60),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppConstants.styleColor.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildAnimatedTitle(),
                        ),
                      ),
                      _buildInfoButton(),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withValues(alpha: 0.10),
                              Colors.purple.withValues(alpha: 0.10),
                              Colors.blue.withValues(alpha: 0.10),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.20),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: 0.20),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.20),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _showProjectPopup,
                            child: Container(
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppConstants.styleColor
                                          .withValues(alpha: 0.82),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (hasTracks) ...[
                  Row(
                    children: [
                      Container(
                        width: addButtonWidth,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppConstants.styleColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _pushHistory();
                              _controller.addTrack();
                              _safeSetHomeState(() {});
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final lastTrack = _controller.tracks.last;
                                _showInstrumentPickerForTrack(lastTrack);
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Добавить дорожку',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[850]?.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                scrollDirection: Axis.horizontal,
                                controller:
                                    _controller.horizontalScrollController,
                                physics: const ClampingScrollPhysics(),
                                itemCount: AppConstants.maxBars,
                                itemBuilder: (context, index) {
                                  final isSelected = selectedBar == index;
                                  final isDraftSelection =
                                      _isTimelineSegmentSelection &&
                                          _hasDraftSegmentSelection &&
                                          _selectedSegmentStartBar == index;
                                  final isActiveSelection =
                                      _isTimelineSegmentSelection &&
                                          _hasActiveSegmentSelection &&
                                          _isBarInSelection(index);

                                  final Color cellColor;
                                  if (isDraftSelection) {
                                    cellColor =
                                        Colors.green.withValues(alpha: 0.12);
                                  } else if (isActiveSelection) {
                                    cellColor =
                                        Colors.green.withValues(alpha: 0.26);
                                  } else if (isSelected) {
                                    cellColor =
                                        Colors.amber.withValues(alpha: 0.18);
                                  } else {
                                    cellColor = Colors.transparent;
                                  }

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onLongPress: () =>
                                        _onTimelineLongPress(index),
                                    onTap: () => _onTimelineTap(index),
                                    child: Container(
                                      width: AppConstants.barWidth,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: cellColor,
                                        border: Border(
                                          right: BorderSide(
                                            color: index ==
                                                    AppConstants.maxBars - 1
                                                ? Colors.transparent
                                                : Colors.amber,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isDraftSelection ||
                                                  isActiveSelection
                                              ? Colors.greenAccent
                                              : Colors.amber,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            _buildPlayheadHeaderOverlay(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: hasTracks
                      ? GestureDetector(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Scrollbar(
                              controller: _controller.verticalScrollController,
                              child: ListView.builder(
                                controller:
                                    _controller.verticalScrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _controller.tracks.length,
                                itemBuilder: (context, index) {
                                  final track = _controller.tracks[index];
                                  final showSelectionForTrack =
                                      _isSelectionVisibleForTrack(track);
                                  final selectionStartBar = showSelectionForTrack
                                      ? _selectedSegmentStartBar
                                      : null;
                                  final selectionEndBar = showSelectionForTrack
                                      ? _selectedSegmentEndBar
                                      : null;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: TrackRowWidget(
                                      track: track,
                                      hasBeenOpened: _controller.openedTracks
                                          .contains(track.id),
                                      onMutePressed: () {
                                        _pushHistory();
                                        _controller.toggleMute(track.id);
                                        _safeSetHomeState(() {});
                                      },
                                      onMuteLongPressed: () {
                                        _pushHistory();
                                        _controller.soloOrResetMute(track.id);
                                        _safeSetHomeState(() {});
                                      },
                                      onEditPressed: () =>
                                          _openPianoRoll(track),
                                      onDeletePressed: () {
                                        if (_hasAnySegmentSelection) {
                                          _deleteSelectedSegmentFromSource();
                                          return;
                                        }

                                        _pushHistory();
                                        _controller.deleteTrack(track.id);
                                        _safeSetHomeState(() {});
                                      },
                                      onRename: (newName) {
                                        _pushHistory();
                                        _controller.renameTrack(
                                            track.id, newName);
                                        _safeSetHomeState(() {});
                                      },
                                      onInstrumentChange: (instrument) {
                                        _pushHistory();
                                        _controller.updateTrackInstrument(
                                          track.id,
                                          instrument,
                                        );
                                        _safeSetHomeState(() {});
                                      },
                                      onVolumeChanged: (value) {
                                        _pushHistory();
                                        _controller.updateTrackVolume(
                                          track.id,
                                          value,
                                        );
                                        _safeSetHomeState(() {});
                                      },
                                      horizontalScrollController: _controller
                                          .horizontalScrollController,
                                      getNotesInBar: _getNotesInBar,
                                      getNoteRange: _getNoteRange,
                                      selectionStartBar: selectionStartBar,
                                      selectionEndBar: selectionEndBar,
                                      onBarLongPress: (barIndex) =>
                                          _onBarLongPress(track, barIndex),
                                      onBarTap: (barIndex) =>
                                          _onBarTap(track, barIndex),
                                      playheadTick: _controller.currentTick,
                                      isPlaying: _controller.isPlaying,
                                      onHorizontalPreviewDrag:
                                          _handleTrackPreviewHorizontalDrag,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : _buildEmptyState(),
                ),
                SizedBox(height: 85 + bottomInset),
              ],
            ),
          ),
          if (hasTracks)
            Positioned(
              left: 10,
              right: 10,
              bottom: 20 + bottomInset,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 50,
                        color: AppConstants.styleColor.withAlpha(50),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.styleColor,
                        ),
                        child: IconButton(
                          onPressed: _canUndo ? _undoLastAction : null,
                          padding: EdgeInsets.zero,
                          splashRadius: 26,
                          icon: Icon(
                            Icons.undo,
                            size: 22,
                            color: Colors.white.withValues(
                              alpha: _canUndo ? 1.0 : 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 45),
                      Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.styleColor,
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (_controller.tracks.isEmpty) {
                              return;
                            }

                            final hasNotes = _controller.tracks
                                .any((t) => t.notes.isNotEmpty);

                            if (!hasNotes) {
                              return;
                            }

                            _controller.togglePlayback();
                            _safeSetHomeState(() {});
                          },
                          padding: EdgeInsets.zero,
                          splashRadius: 30,
                          icon: Icon(
                            _controller.isPlaying
                                ? Icons.stop
                                : Icons.play_arrow,
                            size: 25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 45),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.styleColor,
                        ),
                        child: IconButton(
                          onPressed: _canRedo ? _redoLastAction : null,
                          padding: EdgeInsets.zero,
                          splashRadius: 26,
                          icon: Icon(
                            Icons.redo,
                            size: 22,
                            color: Colors.white.withValues(
                              alpha: _canRedo ? 1.0 : 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Icon(Icons.queue_music, size: 60, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет дорожек',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте первую дорожку, чтобы начать',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _pushHistory();
              _controller.addTrack();
              _safeSetHomeState(() {});
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final lastTrack = _controller.tracks.last;
                _showInstrumentPickerForTrack(lastTrack);
              });
            },
            icon: const Icon(Icons.add, size: 24),
            label: const Text(
              'Создать дорожку',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.styleColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLaunchScreen() {
    Navigator.of(context).pushReplacement(
      FadePageRoute(
        duration: const Duration(milliseconds: 800),
        child: const LaunchScreen(),
      ),
    );
  }
}
