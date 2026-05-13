import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../common/widgets/instrument_picker_dialog.dart';
import '../../../domain/entities/track_model.dart';
import '../../common/widgets/control_button.dart';
import 'pattern_painter.dart';

class TrackRowWidget extends StatelessWidget {
  final Track track;
  final bool hasBeenOpened;
  final VoidCallback onMutePressed;
  final VoidCallback onMuteLongPressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final Function(String) onRename;
  final Function(String) onInstrumentChange;
  final Function(double) onVolumeChanged;

  final ScrollController horizontalScrollController;
  final GestureDragUpdateCallback? onHorizontalPreviewDrag;

  final List<MidiNote> Function(Track, int) getNotesInBar;
  final Map<String, int> Function(Track) getNoteRange;

  final int? selectionStartBar;
  final int? selectionEndBar;
  final Function(int) onBarLongPress;
  final Function(int) onBarTap;

  final int playheadTick;
  final bool isPlaying;

  const TrackRowWidget({
    super.key,
    required this.track,
    required this.hasBeenOpened,
    required this.onMutePressed,
    required this.onMuteLongPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onRename,
    required this.onInstrumentChange,
    required this.onVolumeChanged,
    required this.horizontalScrollController,
    required this.getNotesInBar,
    required this.getNoteRange,
    this.selectionStartBar,
    this.selectionEndBar,
    required this.onBarLongPress,
    required this.onBarTap,
    required this.playheadTick,
    required this.isPlaying,
    this.onHorizontalPreviewDrag,
  });

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: track.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Переименовать дорожку',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Введите название',
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  onRename(value);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  double _currentOffset() {
    if (!horizontalScrollController.hasClients) return 0;
    return horizontalScrollController.offset;
  }

  Widget _buildCompactSlider(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: track.color,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
              thumbColor: track.color,
            ),
            child: Slider(
              value: track.volume,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onVolumeChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteRange = getNoteRange(track);
    final ticksPerBar = AppConstants.ticksPerBar;
    final screenWidth = MediaQuery.of(context).size.width;
    final sideWidth = AppConstants.responsiveTrackInfoWidth(screenWidth) + 9;
    final sliderWidth = (sideWidth * 0.42).clamp(54.0, 88.0).toDouble();

    return Container(
      height: AppConstants.previewHeight + 54,
      decoration: BoxDecoration(
        color: const Color.fromARGB(205, 34, 34, 34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: track.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: sideWidth,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 20, 20, 20),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              border: Border(right: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Column(
              children: [
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: track.color.withValues(alpha: 0.18),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: track.color.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showRenameDialog(context),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  track.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: track.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 13,
                                color: track.color.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: sliderWidth,
                        child: _buildCompactSlider(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: ControlButton(
                              icon: Icons.queue_music,
                              color: track.color,
                              onPressed: () => showInstrumentPickerDialog(
                                context,
                                track,
                                onInstrumentChange,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: ControlButton(
                              icon: track.isMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: track.color,
                              onPressed: onMutePressed,
                              onLongPress: onMuteLongPressed,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: ControlButton(
                              icon: Icons.delete_outline,
                              color: track.color,
                              onPressed: onDeletePressed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: AppConstants.previewHeight + 54,
            color: Colors.amber,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: horizontalScrollController,
                  builder: (context, _) {
                    final offset = _currentOffset();
                    final tickWidth = AppConstants.barWidth / ticksPerBar;
                    final viewportWidth = constraints.maxWidth;

                    final firstVisibleBar =
                        (offset / AppConstants.barWidth).floor().clamp(
                              0,
                              AppConstants.maxBars - 1,
                            );

                    final visibleBarCount =
                        (viewportWidth / AppConstants.barWidth).ceil() + 2;

                    final lastVisibleBar =
                        (firstVisibleBar + visibleBarCount).clamp(
                      0,
                      AppConstants.maxBars,
                    );

                    final visibleBars = <Widget>[];
                    for (int barIndex = firstVisibleBar;
                        barIndex < lastVisibleBar;
                        barIndex++) {
                      final notesInBar = getNotesInBar(track, barIndex);

                      final hasDraftSelection =
                          selectionStartBar != null && selectionEndBar == null;
                      final hasActiveSelection =
                          selectionStartBar != null && selectionEndBar != null;

                      Color segmentHighlightColor = Colors.transparent;
                      if (hasDraftSelection && barIndex == selectionStartBar) {
                        
                        
                        segmentHighlightColor =
                            Colors.green.withValues(alpha: 0.12);
                      } else if (hasActiveSelection) {
                        final startBar = selectionStartBar! < selectionEndBar!
                            ? selectionStartBar!
                            : selectionEndBar!;
                        final endBar = selectionStartBar! > selectionEndBar!
                            ? selectionStartBar!
                            : selectionEndBar!;

                        if (barIndex >= startBar && barIndex <= endBar) {
                          
                          segmentHighlightColor =
                              Colors.green.withValues(alpha: 0.26);
                        }
                      }

                      visibleBars.add(
                        Positioned(
                          left: (barIndex * AppConstants.barWidth) - offset,
                          top: 0,
                          width: AppConstants.barWidth,
                          height: AppConstants.previewHeight + 40,
                          child: GestureDetector(
                            onLongPress: () => onBarLongPress(barIndex),
                            onTap: () => onBarTap(barIndex),
                            child: Container(
                              decoration: BoxDecoration(
                                color: segmentHighlightColor,
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade800,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: Size(
                                      AppConstants.barWidth,
                                      AppConstants.previewHeight + 40,
                                    ),
                                    painter: PatternPainter(
                                      notes: notesInBar,
                                      color: track.color,
                                      barWidth: AppConstants.barWidth,
                                      previewHeight: AppConstants.previewHeight,
                                      minNote: noteRange['min']!,
                                      maxNote: noteRange['max']!,
                                      ticksPerBar: ticksPerBar,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    final playheadX = (playheadTick * tickWidth) - offset;
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: onHorizontalPreviewDrag,
                      child: SizedBox(
                        width: viewportWidth,
                        height: AppConstants.previewHeight + 40,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            ...visibleBars,
                            if (isPlaying &&
                                playheadX >= 0 &&
                                playheadX <= viewportWidth)
                              Positioned(
                                left: playheadX,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 3,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
