import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:midi_util/midi_util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../entities/track_entity.dart';
import 'export_midi_usecase.dart';

class ExportMidiUseCaseImpl implements ExportMidiUseCase {
  @override
  Future<void> execute(
    List<TrackEntity> tracks, {
    required bool share,
    String? fileName,
    int bpm = 120,
  }) async {
    if (tracks.isEmpty) {
      throw Exception('Нет дорожек для экспорта');
    }

    final tracksWithNotes = tracks.where((t) => t.notes.isNotEmpty).toList();
    if (tracksWithNotes.isEmpty) {
      throw Exception('Нет нот для экспорта');
    }

    if (tracksWithNotes.length == 1) {
      final track = tracksWithNotes.first;
      final midiData = await _generateSingleTrackMidi(track, bpm);
      final finalFileName = fileName ?? '${_sanitizeFileName(track.name)}.mid';

      if (share) {
        await _shareMidi(midiData, finalFileName);
      } else {
        await _saveMidi(midiData, finalFileName);
      }
    } else {
      await _exportMultipleTracks(tracksWithNotes, share, bpm);
    }
  }

  Future<void> _exportMultipleTracks(
    List<TrackEntity> tracks,
    bool share,
    int bpm,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final folderName = 'NotRed_Export_${DateTime.now().millisecondsSinceEpoch}';
    final folderPath = '${tempDir.path}/$folderName';
    final folder = Directory(folderPath);

    await folder.create();

    final files = <File>[];
    for (final track in tracks) {
      if (track.notes.isEmpty) continue;

      final midiData = await _generateSingleTrackMidi(track, bpm);
      final fileName = '${_sanitizeFileName(track.name)}.mid';
      final filePath = '$folderPath/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(midiData);
      files.add(file);
    }

    if (share) {
      final zipPath = '${tempDir.path}/$folderName.zip';
      final zipFile = File(zipPath);

      final encoder = ZipEncoder();
      final archive = Archive();

      for (final file in files) {
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(file.path.split('/').last, bytes.length, bytes),
        );
      }

      final zipData = encoder.encode(archive);
      if (zipData != null) {
        await zipFile.writeAsBytes(zipData);

        await Share.shareXFiles(
          [XFile(zipFile.path)],
          text: 'MIDI файлы дорожек из NotRed',
        );

        await zipFile.delete();
      }
    } else {
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final destFolderPath = '${downloadsDir.path}/$folderName';
          final destFolder = Directory(destFolderPath);
          await destFolder.create();

          for (final file in files) {
            final fileName = file.path.split('/').last;
            await file.copy('$destFolderPath/$fileName');
          }
        }
      }
    }

    await folder.delete(recursive: true);
  }

  Future<Uint8List> _generateSingleTrackMidi(TrackEntity track, int bpm) async {
    final midiFile = MIDIFile(numTracks: 1);

    midiFile.addTempo(
      track: 0,
      time: 0,
      tempo: bpm,
    );

    final sortedNotes = List.from(track.notes)
      ..sort((a, b) => a.startTick.compareTo(b.startTick));

    for (final note in sortedNotes) {
      final timeInBeats = note.startTick / AppConstants.ticksPerBeat;
      final durationInBeats = note.durationTicks / AppConstants.ticksPerBeat;

      midiFile.addNote(
        track: 0,
        channel: 0,
        pitch: note.pitch,
        time: timeInBeats,
        duration: durationInBeats,
        volume: 100,
      );
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile =
        File('${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.mid');
    await midiFile.writeFile(tempFile);

    final bytes = await tempFile.readAsBytes();
    await tempFile.delete();

    return bytes;
  }

  String _sanitizeFileName(String name) {
    const cyrillicToLatin = {
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'e',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'kh',
      'ц': 'ts',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sch',
      'ы': 'y',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
      'А': 'A',
      'Б': 'B',
      'В': 'V',
      'Г': 'G',
      'Д': 'D',
      'Е': 'E',
      'Ё': 'E',
      'Ж': 'Zh',
      'З': 'Z',
      'И': 'I',
      'Й': 'Y',
      'К': 'K',
      'Л': 'L',
      'М': 'M',
      'Н': 'N',
      'О': 'O',
      'П': 'P',
      'Р': 'R',
      'С': 'S',
      'Т': 'T',
      'У': 'U',
      'Ф': 'F',
      'Х': 'Kh',
      'Ц': 'Ts',
      'Ч': 'Ch',
      'Ш': 'Sh',
      'Щ': 'Sch',
      'Ы': 'Y',
      'Э': 'E',
      'Ю': 'Yu',
      'Я': 'Ya',
    };

    String result = '';
    for (int i = 0; i < name.length; i++) {
      final char = name[i];
      if (cyrillicToLatin.containsKey(char)) {
        result += cyrillicToLatin[char]!;
      } else if (RegExp(r'[a-zA-Z0-9\s\-_]').hasMatch(char)) {
        result += char;
      } else {
        result += '_';
      }
    }

    return result.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\-_]'), '');
  }

  Future<void> _shareMidi(Uint8List midiData, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(midiData);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'MIDI файл из NotRed',
    );
  }

  Future<void> _saveMidi(Uint8List midiData, String fileName) async {
    if (Platform.isAndroid) {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final file = File('${downloadsDir.path}/$fileName');
        await file.writeAsBytes(midiData);
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$fileName');
        await file.writeAsBytes(midiData);
      }
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$fileName');
      await file.writeAsBytes(midiData);
    }
  }
}