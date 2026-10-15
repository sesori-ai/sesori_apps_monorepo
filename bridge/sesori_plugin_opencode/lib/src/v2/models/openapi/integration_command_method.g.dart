// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'integration_method.g.dart';

@immutable
class IntegrationCommandMethod implements IntegrationMethod {
  const IntegrationCommandMethod({
    required this.id,
    required this.label,
    required this.command,
  });

  factory IntegrationCommandMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationCommandMethod(
      id: json["id"] as String,
      label: json["label"] as String,
      command: (json["command"] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "command",
      "label": label,
      "command": command,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationCommandMethod copyWith({
    String? id,
    String? label,
    List<String>? command,
  }) {
    return IntegrationCommandMethod(
      id: id ?? this.id,
      label: label ?? this.label,
      command: command ?? this.command,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationCommandMethod &&
          other.id == id &&
          other.label == label &&
          const DeepCollectionEquality().equals(other.command, command));

  @override
  int get hashCode => Object.hash(id, label, const DeepCollectionEquality().hash(command));

  final String id;
  final String label;
  final List<String> command;
}
