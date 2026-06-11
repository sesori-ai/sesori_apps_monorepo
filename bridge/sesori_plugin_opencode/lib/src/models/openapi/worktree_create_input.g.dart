// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';

@immutable
class WorktreeCreateInput {
  const WorktreeCreateInput({
    this.name,
    this.startCommand,
  });

  factory WorktreeCreateInput.fromJson(Map<String, dynamic> json) {
    return WorktreeCreateInput(
      name: json["name"] as String?,
      startCommand: json["startCommand"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": ?name,
      "startCommand": ?startCommand,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  WorktreeCreateInput copyWith({
    String? name,
    String? startCommand,
  }) {
    return WorktreeCreateInput(
      name: name ?? this.name,
      startCommand: startCommand ?? this.startCommand,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorktreeCreateInput &&
          other.name == name &&
          other.startCommand == startCommand);

  @override
  int get hashCode => Object.hash(name, startCommand);

  final String? name;
  final String? startCommand;
}
