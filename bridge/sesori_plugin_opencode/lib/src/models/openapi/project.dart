// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class Project {
  const Project({
    required this.id,
    required this.worktree,
    this.vcs,
    this.name,
    this.icon,
    this.commands,
    required this.time,
    required this.sandboxes,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json["id"] as String,
      worktree: json["worktree"] as String,
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
      "worktree": worktree,
      "vcs": ?vcs,
      "name": ?name,
      "icon": ?icon?.toJson(),
      "commands": ?commands?.toJson(),
      "time": time.toJson(),
      "sandboxes": sandboxes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == id &&
          other.worktree == worktree &&
          other.vcs == vcs &&
          other.name == name &&
          other.icon == icon &&
          other.commands == commands &&
          other.time == time &&
          const DeepCollectionEquality().equals(other.sandboxes, sandboxes));

  @override
  int get hashCode => Object.hash(id, worktree, vcs, name, icon, commands, time, const DeepCollectionEquality().hash(sandboxes));

  final String id;
  final String worktree;
  final String? vcs;
  final String? name;
  final ProjectIcon? icon;
  final ProjectCommands? commands;
  final ProjectTime time;
  final List<String> sandboxes;
}

@immutable
class ProjectIcon {
  const ProjectIcon({
    this.url,
    this.overrideValue,
    this.color,
  });

  factory ProjectIcon.fromJson(Map<String, dynamic> json) {
    return ProjectIcon(
      url: json["url"] as String?,
      overrideValue: json["override"] as String?,
      color: json["color"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": ?url,
      "override": ?overrideValue,
      "color": ?color,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectIcon &&
          other.url == url &&
          other.overrideValue == overrideValue &&
          other.color == color);

  @override
  int get hashCode => Object.hash(url, overrideValue, color);

  final String? url;
  final String? overrideValue;
  final String? color;
}

@immutable
class ProjectCommands {
  const ProjectCommands({
    this.start,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectCommands &&
          other.start == start);

  @override
  int get hashCode => start.hashCode;

  final String? start;
}

@immutable
class ProjectTime {
  const ProjectTime({
    required this.created,
    required this.updated,
    this.initialized,
  });

  factory ProjectTime.fromJson(Map<String, dynamic> json) {
    return ProjectTime(
      created: (json["created"] as num).toInt(),
      updated: (json["updated"] as num).toInt(),
      initialized: (json["initialized"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "initialized": ?initialized,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectTime &&
          other.created == created &&
          other.updated == updated &&
          other.initialized == initialized);

  @override
  int get hashCode => Object.hash(created, updated, initialized);

  final int created;
  final int updated;
  final int? initialized;
}
