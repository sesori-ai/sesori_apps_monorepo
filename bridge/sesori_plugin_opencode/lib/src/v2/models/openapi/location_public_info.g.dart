// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class LocationPublicInfo {
  const LocationPublicInfo({
    required this.directory,
    required this.project,
  });

  factory LocationPublicInfo.fromJson(Map<String, dynamic> json) {
    return LocationPublicInfo(
      directory: json["directory"] as String,
      project: LocationPublicInfoProject.fromJson(json["project"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
      "project": project.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  LocationPublicInfo copyWith({
    String? directory,
    LocationPublicInfoProject? project,
  }) {
    return LocationPublicInfo(
      directory: directory ?? this.directory,
      project: project ?? this.project,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationPublicInfo &&
          other.directory == directory &&
          other.project == project);

  @override
  int get hashCode => Object.hash(directory, project);

  final String directory;
  final LocationPublicInfoProject project;
}

@immutable
class LocationPublicInfoProject {
  const LocationPublicInfoProject({
    required this.id,
    required this.directory,
    required this.canonical,
  });

  factory LocationPublicInfoProject.fromJson(Map<String, dynamic> json) {
    return LocationPublicInfoProject(
      id: json["id"] as String,
      directory: json["directory"] as String,
      canonical: json["canonical"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "directory": directory,
      "canonical": canonical,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  LocationPublicInfoProject copyWith({
    String? id,
    String? directory,
    String? canonical,
  }) {
    return LocationPublicInfoProject(
      id: id ?? this.id,
      directory: directory ?? this.directory,
      canonical: canonical ?? this.canonical,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationPublicInfoProject &&
          other.id == id &&
          other.directory == directory &&
          other.canonical == canonical);

  @override
  int get hashCode => Object.hash(id, directory, canonical);

  final String id;
  final String directory;
  final String canonical;
}
