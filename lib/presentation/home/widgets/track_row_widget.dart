import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/track_model.dart';
import 'control_button.dart';
import 'pattern_painter.dart';

class TrackRowWidget extends StatelessWidget {
  final Track track;
  final bool hasBeenOpened;
  final VoidCallback onMutePressed;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final Function(String) onRename; // Новый колбэк для переименования
  final ScrollController horizontalScrollController;
  final List<MidiNote> Function(Track, int) getNotesInBar;
  final Map<String, int> Function(Track) getNoteRange;

  const TrackRowWidget({
    super.key,
    required this.track,
    required this.hasBeenOpened,
    required this.onMutePressed,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onRename,
    required this.horizontalScrollController,
    required this.getNotesInBar,
    required this.getNoteRange,
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

  @override
  Widget build(BuildContext context) {
    final noteRange = getNoteRange(track);

    return Container(
      height: AppConstants.previewHeight + 65,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: track.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // Левая часть
          Container(
            width: 213,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Название дорожки (кликабельное)
                GestureDetector(
                  onTap: () => _showRenameDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                // Кнопки управления
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ControlButton(
                        icon:
                            track.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: track.isMuted ? Colors.red : track.color,
                        onPressed: onMutePressed,
                      ),
                      ControlButton(
                        icon: hasBeenOpened ? Icons.edit : Icons.add,
                        color: track.color,
                        onPressed: onEditPressed,
                      ),
                      ControlButton(
                        icon: Icons.delete_outline,
                        color: Colors.red,
                        onPressed: onDeletePressed,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Вертикальный разделитель
          Container(
            width: 2,
            height: AppConstants.previewHeight + 65,
            color: Colors.amber,
          ),

          // Правая часть - превью паттернов
          Expanded(
            child: ListView.builder(
              controller: horizontalScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.maxBars,
              itemBuilder: (context, barIndex) {
                final notesInBar = getNotesInBar(track, barIndex);
                return Container(
                  width: AppConstants.barWidth,
                  height: AppConstants.previewHeight + 50,
                  decoration: BoxDecoration(
                    border: Border(
                      right:
                          BorderSide(color: Colors.grey.shade800, width: 1.0),
                    ),
                  ),
                  child: CustomPaint(
                    painter: PatternPainter(
                      notes: notesInBar,
                      color: track.color,
                      barWidth: AppConstants.barWidth,
                      previewHeight: AppConstants.previewHeight,
                      minNote: noteRange['min']!,
                      maxNote: noteRange['max']!,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
