// lib/presentation/home/home_controller.dart (дополнения)
import 'package:flutter/material.dart';
import 'package:not_red_sound/core/constants/app_constants.dart';
import '../../data/models/track_model.dart';
import '../../data/models/pattern_segment.dart';
import '../../data/repositories/track_repository.dart';
import '../../domain/usecases/export_midi_usecase_impl.dart';
import '../../core/services/audio_service.dart';

class HomeController extends ChangeNotifier {
  final TrackRepository _repository;
  final ExportMidiUseCaseImpl _exportMidiUseCase;
  final AudioService _audioService = AudioService();
  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();
  final Set<String> openedTracks = {};
  
  // Хранилище сегментов для каждой дорожки
  final Map<String, PatternSegment?> _trackSegments = {}; // trackId -> segment
  final Map<String, PatternSegment> _savedSegments = {}; // Сохраненные сегменты

  HomeController(this._repository) : _exportMidiUseCase = ExportMidiUseCaseImpl();

  List<Track> get tracks => _repository.getTracks().cast<Track>();
  bool get isPlaying => _audioService.isPlaying;
  int get currentTick => _audioService.currentTick;
  
  // Получить сегмент дорожки
  PatternSegment? getTrackSegment(String trackId) => _trackSegments[trackId];
  
  // Установить сегмент для дорожки (при копировании)
  void setTrackSegment(String trackId, PatternSegment segment) {
    _trackSegments[trackId] = segment;
    notifyListeners();
  }
  
  // Очистить сегмент дорожки
  void clearTrackSegment(String trackId) {
    _trackSegments.remove(trackId);
    notifyListeners();
  }
  
  // Сохранить сегмент в библиотеку
  void saveSegment(PatternSegment segment) {
    _savedSegments[segment.id] = segment;
    notifyListeners();
  }
  
  // Получить все сохраненные сегменты
  List<PatternSegment> getSavedSegments() => _savedSegments.values.toList();
  
  // Удалить сохраненный сегмент
  void deleteSavedSegment(String segmentId) {
    _savedSegments.remove(segmentId);
    notifyListeners();
  }
  
  // Скопировать сегмент на указанный такт
  void copySegmentToBar(String trackId, PatternSegment segment, int targetBarIndex) {
    final track = tracks.firstWhere((t) => t.id == trackId);
    final ticksPerBar = AppConstants.ticksPerBeat * AppConstants.beatsPerBar;
    
    final newNotes = segment.copyNotesToBar(targetBarIndex, ticksPerBar);
    
    // Удаляем старые ноты в этом диапазоне тактов
    final startTick = targetBarIndex * ticksPerBar;
    final endTick = (targetBarIndex + segment.barLength) * ticksPerBar;
    
    final updatedNotes = track.notes
        .where((note) => note.startTick < startTick || note.startTick >= endTick)
        .toList();
    
    updatedNotes.addAll(newNotes);
    
    // Обновляем дорожку
    final updatedTrack = Track(
      id: track.id,
      name: track.name,
      isMuted: track.isMuted,
      color: track.color,
      notes: updatedNotes,
      instrument: track.instrument,
    );
    
    _repository.updateTrack(updatedTrack);
    notifyListeners();
  }
  
  // Создать сегмент из выбранных тактов дорожки
  PatternSegment? createSegmentFromBars(String trackId, int startBar, int barCount) {
    final track = tracks.firstWhere((t) => t.id == trackId);
    final ticksPerBar = AppConstants.ticksPerBeat * AppConstants.beatsPerBar;
    
    final startTick = startBar * ticksPerBar;
    final endTick = (startBar + barCount) * ticksPerBar;
    
    final notesInRange = track.notes
        .where((note) => note.startTick >= startTick && note.startTick < endTick)
        .map((note) => MidiNote(
          pitch: note.pitch,
          startTick: note.startTick - startTick, // Нормализуем для сегмента
          durationTicks: note.durationTicks,
        ))
        .toList();
    
    if (notesInRange.isEmpty) return null;
    
    return PatternSegment(
      id: DateTime.now().toString(),
      name: 'Сегмент ${_savedSegments.length + 1}',
      notes: notesInRange,
      barLength: barCount,
      createdAt: DateTime.now(),
    );
  }

  // Остальные методы без изменений...
  void addTrack() {
    final newTrack = Track(
      id: DateTime.now().toString(),
      name: 'Дорожка ${tracks.length + 1}',
      color: Colors.primaries[tracks.length % Colors.primaries.length],
      notes: [],
      instrument: 'Piano',
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
    final index = tracks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final track = tracks[index];
      final updatedTrack = Track(
        id: track.id,
        name: newName,
        isMuted: track.isMuted,
        color: track.color,
        notes: track.notes,
        instrument: track.instrument,
      );
      _repository.updateTrack(updatedTrack);
      notifyListeners();
    }
  }

  void updateTrackInstrument(String id, String instrument) {
    final index = tracks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final track = tracks[index];
      final updatedTrack = Track(
        id: track.id,
        name: track.name,
        isMuted: track.isMuted,
        color: track.color,
        notes: track.notes,
        instrument: instrument,
      );
      _repository.updateTrack(updatedTrack);
      notifyListeners();
    }
  }

  void togglePlayback() {
    if (_audioService.isPlaying) {
      _audioService.stopPlayback();
    } else {
      final tracksWithNotes = tracks.where((t) => 
        !t.isMuted && t.notes.isNotEmpty
      ).toList();
      
      if (tracksWithNotes.isEmpty) {
        debugPrint('⚠️ Нет дорожек с нотами для воспроизведения');
        return;
      }
      
      for (var track in tracksWithNotes) {
        _audioService.setTrackInstrument(track.id, track.instrument);
      }
      
      _audioService.startPlayback(
        tracksWithNotes, 
        onTick: () {
          notifyListeners();
        },
        onFinished: () {
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  Future<void> exportMidi({required bool share, String? fileName, int bpm = 120}) async {
    try {
      await _exportMidiUseCase.execute(
        tracks, 
        share: share, 
        fileName: fileName,
        bpm: bpm,
      );
    } catch (e) {
      rethrow;
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