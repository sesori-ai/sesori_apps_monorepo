// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class WorktreeRemoveInput {
  const WorktreeRemoveInput({
    this.directory = '',
  });

  factory WorktreeRemoveInput.fromJson(Map<String, dynamic> json) {
    return WorktreeRemoveInput(
      directory: (json["directory"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  WorktreeRemoveInput copyWith({
    String? directory,
  }) {
    return WorktreeRemoveInput(
      directory: directory ?? this.directory,
    );
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
