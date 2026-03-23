import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';

Future<void> showInstrumentPickerDialog(
  BuildContext context,
  Track track,
  Function(String) onInstrumentSelected,
) async {
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

  return showDialog(
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
                        onInstrumentSelected(instrument);
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