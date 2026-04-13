import 'package:flutter/material.dart';

import '../../data/models/track_model.dart';
import '../../core/services/audio_service.dart';

void showInstrumentPickerDialog(
  BuildContext context,
  Track track,
  Function(String) onInstrumentSelected,
) {
  final instruments = AudioService.instruments.keys.toList();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: track.color,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// 🔴 Заголовок (заливка цветом дорожки)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  color: track.color.withValues(alpha: 0.25),
                  child: const Text(
                    'Выберите инструмент',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// 🔴 Полоса
                Container(
                  height: 3,
                  width: double.infinity,
                  color: track.color,
                ),

                /// 🔴 Список
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: instruments.length,
                  itemBuilder: (context, index) {
                    final instrument = instruments[index];
                    final isSelected = track.instrument == instrument;

                    return InkWell(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        onInstrumentSelected(instrument);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        color: isSelected
                            ? track.color.withValues(alpha: 0.15)
                            : Colors.transparent,
                        child: Text(
                          instrument,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey[300],
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}