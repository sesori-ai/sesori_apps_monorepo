// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';

@immutable
class CommandInfo {
  const CommandInfo({
    required this.name,
    required this.description,
  });

  factory CommandInfo.fromJson(Map<String, dynamic> json) {
    return CommandInfo(
      name: json["name"] as String,
      description: json["description"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": ?description,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  CommandInfo copyWith({
    String? name,
    String? description,
  }) {
    return CommandInfo(
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CommandInfo &&
          other.name == name &&
          other.description == description);

  @override
  int get hashCode => Object.hash(name, description);

  final String name;
  final String? description;
}
