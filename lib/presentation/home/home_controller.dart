import 'package:flutter/material.dart';
import '../../data/models/track_model.dart';
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

  HomeController(this._repository) : _exportMidiUseCase = ExportMidiUseCaseImpl();

  List<Track> get tracks => _repository.getTracks().cast<Track>();
  bool get isPlaying => _audioService.isPlaying;
  int get currentTick => _audioService.currentTick;

  void addTrack() {
    final newTrack = Track(
      id: DateTime.now().toString(),
      name: 'Дорожка ${tracks.length + 1}',
      color: Colors.primaries[tracks.length % Colors.primaries.length],
      notes: [],
      instrument: 'Piano', // Инструмент по умолчанию
    );
    _repository.addTrack(newTrack);
    notifyListeners();
  }

  void deleteTrack(String id) {
    _repository.deleteTrack(id);
    openedTracks.remove(id);
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
        instrument: track.instrument, // Сохраняем инструмент
      );
      _repository.updateTrack(updatedTrack);
      notifyListeners();
    }
  }

  // Обновление инструмента дорожки
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
      
      // Для каждой дорожки устанавливаем её инструмент перед воспроизведением
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