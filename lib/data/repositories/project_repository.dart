import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/styles/project_style.dart';
import '../../core/styles/project_styles.dart';
import '../../domain/entities/project_snapshot.dart';
import '../../domain/repositories/project_repository_interface.dart';
import '../models/track_model.dart';

class ProjectRepository implements ProjectRepositoryInterface {
  Future<File> _projectFile({ProjectStyleType? styleType}) async {
    final dir = await getApplicationDocumentsDirectory();
    final resolvedType = styleType ?? ProjectStyleType.standard;
    final styleId = ProjectStyles.byType(resolvedType).id;
    return File('${dir.path}/notred_project_$styleId.json');
  }

  @override
  Future<void> save(ProjectSnapshot snapshot,
      {ProjectStyleType? styleType}) async {
    final file = await _projectFile(styleType: styleType);

    final data = {
      'bpm': snapshot.bpm,
      'totalBars': snapshot.totalBars,
      'beatsPerBar': snapshot.beatsPerBar,
      'ticksPerBeat': snapshot.ticksPerBeat,
      'styleId': snapshot.styleId,
      'tracks': snapshot.tracks
          .whereType<Track>()
          .map((track) => track.toJson())
          .toList(),
    };

    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<ProjectSnapshot?> load({ProjectStyleType? styleType}) async {
    try {
      final file = await _projectFile(styleType: styleType);
      if (!await file.exists()) return null;

      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final tracks = (json['tracks'] as List<dynamic>? ?? [])
          .map((entry) => Track.fromJson(Map<String, dynamic>.from(entry)))
          .toList();

      return ProjectSnapshot(
        bpm: json['bpm'] as int? ?? 60,
        totalBars: json['totalBars'] as int? ?? 20,
        beatsPerBar: json['beatsPerBar'] as int? ?? 4,
        ticksPerBeat: json['ticksPerBeat'] as int? ?? 4,
        styleId: json['styleId'] as String? ??
            ProjectStyles.byType(styleType ?? ProjectStyleType.standard).id,
        tracks: tracks,
      );
    } catch (_) {
      return null;
    }
  }
}
