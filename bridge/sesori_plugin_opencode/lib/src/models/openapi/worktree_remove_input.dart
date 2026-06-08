// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.979442Z

import 'package:meta/meta.dart';

@immutable
class WorktreeRemoveInput {
  const WorktreeRemoveInput({
    required this.directory,
  });

  factory WorktreeRemoveInput.fromJson(Map<String, dynamic> json) {
    return WorktreeRemoveInput(
      directory: json["directory"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorktreeRemoveInput &&
          other.directory == directory);

  @override
  int get hashCode => directory.hashCode;

  final String directory;
}
