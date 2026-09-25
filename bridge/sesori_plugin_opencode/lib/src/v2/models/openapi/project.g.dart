// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'project_commands.g.dart';
import 'project_icon.g.dart';
import 'project_time.g.dart';

@immutable
class Project {
  const Project({
    required this.id,
    required this.canonical,
    required this.vcs,
    required this.name,
    required this.icon,
    required this.commands,
    required this.time,
    required this.sandboxes,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json["id"] as String,
      canonical: json["canonical"] as String,
      vcs: json["vcs"] as String?,
      name: json["name"] as String?,
      icon: json["icon"] == null ? null : ProjectIcon.fromJson(json["icon"] as Map<String, dynamic>),
      commands: json["commands"] == null ? null : ProjectCommands.fromJson(json["commands"] as Map<String, dynamic>),
      time: ProjectTime.fromJson(json["time"] as Map<String, dynamic>),
      sandboxes: (json["sandboxes"] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "canonical": canonical,
      "vcs": ?vcs,
      "name": ?name,
      "icon": ?icon?.toJson(),
      "commands": ?commands?.toJson(),
      "time": time.toJson(),
      "sandboxes": sandboxes,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Project copyWith({
    String? id,
    String? canonical,
    String? vcs,
    String? name,
    ProjectIcon? icon,
    ProjectCommands? commands,
    ProjectTime? time,
    List<String>? sandboxes,
  }) {
    return Project(
      id: id ?? this.id,
      canonical: canonical ?? this.canonical,
      vcs: vcs ?? this.vcs,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      commands: commands ?? this.commands,
      time: time ?? this.time,
      sandboxes: sandboxes ?? this.sandboxes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == id &&
          other.canonical == canonical &&
          other.vcs == vcs &&
          other.name == name &&
          other.icon == icon &&
          other.commands == commands &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.sandboxes, sandboxes));

  @override
  int get hashCode => Object.hash(id, canonical, vcs, name, icon, commands, time, const DeepCollectionEquality().hash(sandboxes));

  final String id;
  final String canonical;
  final String? vcs;
  final String? name;
  final ProjectIcon? icon;
  final ProjectCommands? commands;
  final ProjectTime time;
  final List<String> sandboxes;
}
