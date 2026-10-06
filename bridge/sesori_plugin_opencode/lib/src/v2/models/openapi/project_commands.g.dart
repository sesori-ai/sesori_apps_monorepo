// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:meta/meta.dart';

@immutable
class ProjectCommands {
  const ProjectCommands({
    required this.start,
  });

  factory ProjectCommands.fromJson(Map<String, dynamic> json) {
    return ProjectCommands(
      start: json["start"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": ?start,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProjectCommands copyWith({
    String? start,
  }) {
    return ProjectCommands(
      start: start ?? this.start,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectCommands &&
          other.start == start);

  @override
  int get hashCode => start.hashCode;

  final String? start;
}
