import 'package:flutter/material.dart';

enum ProjectStyleType {
  rock,
  electro,
  classic,
  standard,
}

class DefaultTrackTemplate {
  final String name;
  final String instrument;

  const DefaultTrackTemplate({
    required this.name,
    required this.instrument,
  });
}

class ProjectStyle {
  final ProjectStyleType type;
  final String id;
  final String displayName;
  final String backgroundAsset;
  final Color primaryColor;
  final Color secondaryColor;
  final List<Color> trackPalette;
  final Map<String, List<String>> instrumentCategories;
  final List<DefaultTrackTemplate> starterTracks;

  const ProjectStyle({
    required this.type,
    required this.id,
    required this.displayName,
    required this.backgroundAsset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackPalette,
    required this.instrumentCategories,
    required this.starterTracks,
  });

  String get defaultInstrument =>
      starterTracks.isEmpty ? 'Пианино' : starterTracks.first.instrument;

  String defaultTrackName(int index) {
    if (starterTracks.isEmpty) {
      return 'Дорожка ${index + 1}';
    }
    if (index < starterTracks.length) {
      return starterTracks[index].name;
    }
    return 'Дорожка ${index + 1}';
  }

  String defaultTrackInstrument(int index) {
    if (starterTracks.isEmpty) {
      return 'Пианино';
    }
    if (index < starterTracks.length) {
      return starterTracks[index].instrument;
    }
    return starterTracks[index % starterTracks.length].instrument;
  }

  Color colorForTrack(int index) {
    if (trackPalette.isEmpty) {
      return Colors.blue;
    }
    return trackPalette[index % trackPalette.length];
  }
}