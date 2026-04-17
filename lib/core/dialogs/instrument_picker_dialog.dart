import 'package:flutter/material.dart';

import '../../core/services/audio_service.dart';
import '../../data/models/track_model.dart';

class _InstrumentSection {
  final String title;
  final List<String> instruments;
  bool isExpanded;

  _InstrumentSection({
    required this.title,
    required this.instruments,
    this.isExpanded = false,
  });
}

class _InstrumentPickerDialog extends StatefulWidget {
  final Track track;
  final Function(String) onInstrumentSelected;

  const _InstrumentPickerDialog({
    required this.track,
    required this.onInstrumentSelected,
  });

  @override
  State<_InstrumentPickerDialog> createState() =>
      _InstrumentPickerDialogState();
}

class _InstrumentPickerDialogState extends State<_InstrumentPickerDialog> {
  late final List<_InstrumentSection> sections;

  @override
  void initState() {
    super.initState();

    int selectedSectionIndex = -1;

    sections = AudioService.instrumentCategories.entries.map((entry) {
      return _InstrumentSection(
        title: entry.key,
        instruments: entry.value,
        isExpanded: false,
      );
    }).toList();

    for (int i = 0; i < sections.length; i++) {
      if (sections[i].instruments.contains(widget.track.instrument)) {
        selectedSectionIndex = i;
        break;
      }
    }

    if (selectedSectionIndex != -1) {
      sections[selectedSectionIndex].isExpanded = true;
    } else if (sections.isNotEmpty) {
      sections.first.isExpanded = true;
    }
  }

  void _toggleSection(int index) {
    setState(() {
      final wasExpanded = sections[index].isExpanded;

      for (int i = 0; i < sections.length; i++) {
        sections[i].isExpanded = false;
      }

      sections[index].isExpanded = !wasExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.track.color,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  color: widget.track.color.withValues(alpha: 0.25),
                  child: const Text(
                    'Выберите инструмент',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  height: 3,
                  width: double.infinity,
                  color: widget.track.color,
                ),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                      itemCount: sections.length,
                      itemBuilder: (context, sectionIndex) {
                        final section = sections[sectionIndex];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _toggleSection(sectionIndex),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          section.title,
                                          style: TextStyle(
                                            color: widget.track.color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        section.isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: widget.track.color,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (section.isExpanded) ...[
                                const SizedBox(height: 8),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: section.instruments.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.9,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemBuilder: (context, instrumentIndex) {
                                    final instrument =
                                        section.instruments[instrumentIndex];
                                    final isSelected =
                                        widget.track.instrument == instrument;

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onInstrumentSelected(instrument);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? widget.track.color
                                                  .withValues(alpha: 0.18)
                                              : Colors.grey[900],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? widget.track.color
                                                : Colors.white.withValues(
                                                    alpha: 0.06,
                                                  ),
                                            width: isSelected ? 1.4 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            instrument,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.05,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey[300],
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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
}

void showInstrumentPickerDialog(
  BuildContext context,
  Track track,
  Function(String) onInstrumentSelected,
) {
  showDialog(
    context: context,
    builder: (_) => _InstrumentPickerDialog(
      track: track,
      onInstrumentSelected: onInstrumentSelected,
    ),
  );
}