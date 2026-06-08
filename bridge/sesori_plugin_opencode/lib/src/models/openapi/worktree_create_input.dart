// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.262999Z

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
