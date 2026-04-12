import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/dialogs/instrument_picker_dialog.dart';
import '../../../data/models/pattern_segment.dart';
import '../../../data/models/track_model.dart';
import 'control_button.dart';
import 'pattern_painter.dart';

class TrackRowWidget extends StatelessWidget {
  final Track track;
  final bool hasBeenOpened;
  final VoidCallback onMutePressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final Function(String) onRename;
  final Function(String) onInstrumentChange;

  /// Используется только как источник общего horizontal offset.
  final ScrollController horizontalScrollController;

  final List<MidiNote> Function(Track, int) getNotesInBar;
  final Map<String, int> Function(Track) getNoteRange;

  final PatternSegment? currentSegment;
  final Function(int) onBarLongPress;
  final Function(int) onBarTap;

  final int playheadTick;
  final bool isPlaying;

  const TrackRowWidget({
    super.key,
    required this.track,
    required this.hasBeenOpened,
    required this.onMutePressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onRename,
    required this.onInstrumentChange,
    required this.horizontalScrollController,
    required this.getNotesInBar,
    required this.getNoteRange,
    this.currentSegment,
    required this.onBarLongPress,
    required this.onBarTap,
    required this.playheadTick,
    required this.isPlaying,
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
              hintStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
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
                if (controller.text.isNotEmpty) {
                  onRename(controller.text);
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

  @override
  Widget build(BuildContext context) {
    final noteRange = getNoteRange(track);
    final hasSegment = currentSegment != null;
    final ticksPerBar = AppConstants.ticksPerBar;

    return Container(
      height: AppConstants.previewHeight + 65,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: track.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 213,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showRenameDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: track.color.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            track.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: track.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          size: 16,
                          color: track.color.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ControlButton(
                        icon: Icons.music_note,
                        color: track.color,
                        onPressed: () => showInstrumentPickerDialog(
                          context,
                          track,
                          onInstrumentChange,
                        ),
                      ),
                      ControlButton(
                        icon:
                            track.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: track.isMuted ? Colors.red : track.color,
                        onPressed: onMutePressed,
                      ),
                      ControlButton(
                        icon: Icons.delete_outline,
                        color: track.color,
                        onPressed: onDeletePressed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 2,
            height: AppConstants.previewHeight + 65,
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
                      final isEmpty = notesInBar.isEmpty;
                      final isSegmentAvailable = hasSegment && isEmpty;

                      visibleBars.add(
                        Positioned(
                          left: (barIndex * AppConstants.barWidth) - offset,
                          top: 0,
                          width: AppConstants.barWidth,
                          height: AppConstants.previewHeight + 50,
                          child: GestureDetector(
                            onLongPress: () => onBarLongPress(barIndex),
                            onTap: () => onBarTap(barIndex),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade800,
                                    width: 1.0,
                                  ),
                                ),
                                color: isSegmentAvailable
                                    ? track.color.withValues(alpha: 0.15)
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: Size(
                                      AppConstants.barWidth,
                                      AppConstants.previewHeight + 50,
                                    ),
                                    painter: PatternPainter(
                                      notes: notesInBar,
                                      color: track.color,
                                      barWidth: AppConstants.barWidth,
                                      previewHeight:
                                          AppConstants.previewHeight,
                                      minNote: noteRange['min']!,
                                      maxNote: noteRange['max']!,
                                      ticksPerBar: ticksPerBar,
                                    ),
                                  ),
                                  if (isSegmentAvailable)
                                    Positioned(
                                      bottom: 0,
                                      left: 4,
                                      right: 4,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: track.color,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
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

                    return SizedBox(
                      width: viewportWidth,
                      height: AppConstants.previewHeight + 50,
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