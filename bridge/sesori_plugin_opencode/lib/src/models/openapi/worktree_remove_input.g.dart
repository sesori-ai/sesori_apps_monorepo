// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

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
