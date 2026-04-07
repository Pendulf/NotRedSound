import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:not_red_sound/core/constants/app_constants.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/audio_service.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/models/track_model.dart';
import '../../data/repositories/track_repository.dart';
import '../../domain/usecases/export_midi_usecase_impl.dart';

class HomeController extends ChangeNotifier {
  final TrackRepository _repository;
  final ExportMidiUseCaseImpl _exportMidiUseCase;
  final AudioService _audioService = AudioService();

  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  final Set<String> openedTracks = {};
  final Map<String, PatternSegment?> _trackSegments = {};
  final Map<String, PatternSegment> _savedSegments = {};

  HomeController(this._repository)
      : _exportMidiUseCase = ExportMidiUseCaseImpl();

  List<Track> get tracks => _repository.getTracks().cast<Track>();
  bool get isPlaying => _audioService.isPlaying;
  int get currentTick => _audioService.currentTick;

  PatternSegment? getTrackSegment(String trackId) => _trackSegments[trackId];

  void setTrackSegment(String trackId, PatternSegment segment) {
    _trackSegments[trackId] = segment;
    notifyListeners();
  }

  void clearTrackSegment(String trackId) {
    _trackSegments.remove(trackId);
    notifyListeners();
  }

  void saveSegment(PatternSegment segment) {
    _savedSegments[segment.id] = segment;
    notifyListeners();
  }

  List<PatternSegment> getSavedSegments() => _savedSegments.values.toList();

  void deleteSavedSegment(String segmentId) {
    _savedSegments.remove(segmentId);
    notifyListeners();
  }

  int get _ticksPerBar => AppConstants.ticksPerBar;

  Track? _findTrack(String trackId) {
    try {
      return tracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  List<MidiNote> _replaceNotesInRange({
    required List<MidiNote> sourceNotes,
    required int rangeStart,
    required int rangeEnd,
    required List<MidiNote> insertingNotes,
  }) {
    final result = <MidiNote>[];

    for (final note in sourceNotes) {
      final intersects = note.intersectsRange(rangeStart, rangeEnd);

      if (!intersects) {
        result.add(note);
        continue;
      }

      if (note.startTick < rangeStart) {
        final leftDuration = rangeStart - note.startTick;
        if (leftDuration > 0) {
          result.add(note.copyWith(durationTicks: leftDuration));
        }
      }

      if (note.endTick > rangeEnd) {
        final rightStart = rangeEnd;
        final rightDuration = note.endTick - rangeEnd;
        if (rightDuration > 0) {
          result.add(
            note.copyWith(
              startTick: rightStart,
              durationTicks: rightDuration,
            ),
          );
        }
      }
    }

    result.addAll(insertingNotes);

    result.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });

    return result;
  }

  PatternSegment? createSegmentFromBars(
    String trackId,
    int startBar,
    int barCount,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return null;

    final startTick = startBar * _ticksPerBar;
    final endTick = (startBar + barCount) * _ticksPerBar;

    final notesInRange = <MidiNote>[];

    for (final note in track.notes) {
      if (!note.intersectsRange(startTick, endTick)) continue;

      final clippedStart =
          note.startTick < startTick ? startTick : note.startTick;
      final clippedEnd = note.endTick > endTick ? endTick : note.endTick;
      final clippedDuration = clippedEnd - clippedStart;

      if (clippedDuration <= 0) continue;

      notesInRange.add(
        MidiNote(
          pitch: note.pitch,
          startTick: clippedStart - startTick,
          durationTicks: clippedDuration,
        ),
      );
    }

    if (notesInRange.isEmpty) return null;

    notesInRange.sort((a, b) {
      if (a.startTick != b.startTick) {
        return a.startTick.compareTo(b.startTick);
      }
      return a.pitch.compareTo(b.pitch);
    });

    return PatternSegment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Сегмент ${_savedSegments.length + 1}',
      notes: notesInRange,
      barLength: barCount,
      createdAt: DateTime.now(),
    );
  }

  void copySegmentToBar(
    String trackId,
    PatternSegment segment,
    int targetBarIndex,
  ) {
    final track = _findTrack(trackId);
    if (track == null) return;

    final targetStart = targetBarIndex * _ticksPerBar;
    final targetEnd = targetStart + (segment.barLength * _ticksPerBar);

    final insertingNotes = segment.copyNotesToBar(targetBarIndex, _ticksPerBar);

    final updatedNotes = _replaceNotesInRange(
      sourceNotes: track.notes,
      rangeStart: targetStart,
      rangeEnd: targetEnd,
      insertingNotes: insertingNotes,
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
  }

  void deleteNotesInBar(String trackId, int barIndex) {
    final track = _findTrack(trackId);
    if (track == null) return;

    final startTick = barIndex * _ticksPerBar;
    final endTick = startTick + _ticksPerBar;

    final updatedNotes = _replaceNotesInRange(
      sourceNotes: track.notes,
      rangeStart: startTick,
      rangeEnd: endTick,
      insertingNotes: const [],
    );

    _repository.updateTrack(track.copyWith(notes: updatedNotes));
    notifyListeners();
  }

  void addTrack() {
    final newTrack = Track(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Дорожка ${tracks.length + 1}',
      color: Colors.primaries[tracks.length % Colors.primaries.length],
      notes: [],
      instrument: 'Пианино',
    );
    _repository.addTrack(newTrack);
    notifyListeners();
  }

  void deleteTrack(String id) {
    _repository.deleteTrack(id);
    openedTracks.remove(id);
    _trackSegments.remove(id);

    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
    }

    notifyListeners();
  }

  void toggleMute(String id) {
    _repository.toggleMute(id);
    notifyListeners();
  }

  void markAsOpened(String id) {
    openedTracks.add(id);
    notifyListeners();
  }

  void updateTrack(Track updatedTrack) {
    _repository.updateTrack(updatedTrack);
    notifyListeners();
  }

  void renameTrack(String id, String newName) {
    final track = _findTrack(id);
    if (track == null) return;

    _repository.updateTrack(track.copyWith(name: newName));
    notifyListeners();
  }

  void updateTrackInstrument(String id, String instrument) {
    final track = _findTrack(id);
    if (track == null) return;

    _repository.updateTrack(track.copyWith(instrument: instrument));
    notifyListeners();
  }

  void togglePlayback() {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
      notifyListeners();
      return;
    }

    final tracksWithNotes =
        tracks.where((t) => !t.isMuted && t.notes.isNotEmpty).toList();

    if (tracksWithNotes.isEmpty) {
      debugPrint('⚠️ Нет дорожек с нотами для воспроизведения');
      return;
    }

    for (final track in tracksWithNotes) {
      _audioService.setTrackInstrument(track.id, track.instrument);
    }

    _audioService.startPlayback(
      tracksWithNotes,
      onTick: notifyListeners,
      onFinished: notifyListeners,
    );

    notifyListeners();
  }

  Future<void> exportMidi({
    required bool share,
    String? fileName,
    int bpm = 120,
  }) async {
    await _exportMidiUseCase.execute(
      tracks,
      share: share,
      fileName: fileName,
      bpm: bpm,
    );
  }

  Future<File> _projectFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/notred_project.json');
  }

  Future<void> saveProject() async {
    final file = await _projectFile();

    final data = {
      'bpm': AppConstants.bpm,
      'totalBars': AppConstants.totalBars,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };

    await file.writeAsString(jsonEncode(data));
  }

  Future<bool> loadProject() async {
    try {
      final file = await _projectFile();
      if (!await file.exists()) {
        return false;
      }

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      final bpm = json['bpm'] as int? ?? AppConstants.bpm;
      final totalBars = json['totalBars'] as int? ?? AppConstants.totalBars;

      AppConstants.updateBpm(bpm);
      AppConstants.updateTotalBars(totalBars);

      final loadedTracks = (json['tracks'] as List<dynamic>? ?? [])
          .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final existingIds = tracks.map((t) => t.id).toList();
      for (final id in existingIds) {
        _repository.deleteTrack(id);
      }

      for (final track in loadedTracks) {
        _repository.addTrack(track);
      }

      notifyListeners();
      return loadedTracks.isNotEmpty;
    } catch (e) {
      debugPrint('Load project error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
    super.dispose();
  }
}