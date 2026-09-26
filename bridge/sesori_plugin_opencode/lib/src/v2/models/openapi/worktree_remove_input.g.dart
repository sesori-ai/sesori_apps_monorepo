// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class WorktreeRemoveInput {
  const WorktreeRemoveInput({
    required this.projectID,
    required this.directory,
    required this.force,
  });

  factory WorktreeRemoveInput.fromJson(Map<String, dynamic> json) {
    return WorktreeRemoveInput(
      projectID: json["projectID"] as String,
      directory: json["directory"] as String,
      force: json["force"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "projectID": projectID,
      "directory": directory,
      "force": force,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  WorktreeRemoveInput copyWith({
    String? projectID,
    String? directory,
    bool? force,
  }) {
    return WorktreeRemoveInput(
      projectID: projectID ?? this.projectID,
      directory: directory ?? this.directory,
      force: force ?? this.force,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorktreeRemoveInput &&
          other.projectID == projectID &&
          other.directory == directory &&
          other.force == force);

  @override
  int get hashCode => Object.hash(projectID, directory, force);

  final String projectID;
  final String directory;
  final bool force;
}
