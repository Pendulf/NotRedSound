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
  final Function(String) onRename;
  final Function(String) onInstrumentChange; // Колбэк для смены инструмента
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
    required this.onInstrumentChange,
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

  void _showInstrumentPicker(BuildContext context) {
    final List<String> instruments = [
      'Пианино',
      'Электро пианино',
      'Орган',
      'Гитара',
      'Бас',
      'Арфа',
      'Синт',
      'Барабаны',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Выберите инструмент',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: instruments.length,
                itemBuilder: (context, index) {
                  final instrument = instruments[index];
                  final isSelected = instrument == track.instrument;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? track.color.withValues(alpha: 0.3)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // Обновляем инструмент через колбэк
                          onInstrumentChange(instrument);
                          // Закрываем диалог
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              if (isSelected)
                                Icon(Icons.check, color: track.color, size: 20),
                              if (isSelected) const SizedBox(width: 8),
                              Text(
                                instrument,
                                style: TextStyle(
                                  color: isSelected ? track.color : Colors.white,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
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
                // Название дорожки (кликабельное для переименования)
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
                      // Кнопка выбора инструмента
                      ControlButton(
                        icon: Icons.music_note,
                        color: track.color,
                        onPressed: () => _showInstrumentPicker(context),
                      ),
                      ControlButton(
                        icon:
                            track.isMuted ? Icons.volume_off : Icons.volume_up,
                        color: track.isMuted ? Colors.red : track.color,
                        onPressed: onMutePressed,
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

          // Правая часть - превью паттернов (кликабельная для редактирования)
          Expanded(
            child: GestureDetector(
              onTap: onEditPressed, // Открываем Piano Roll по нажатию на превью
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
          ),
        ],
      ),
    );
  }
}