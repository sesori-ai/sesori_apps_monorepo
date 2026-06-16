// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventProjectUpdated implements Event {
  const EventProjectUpdated({
    required this.id,
    required this.properties,
  });

  factory EventProjectUpdated.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdated(
      id: json["id"] as String,
      properties: EventProjectUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "project.updated",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventProjectUpdated copyWith({
    String? id,
    EventProjectUpdatedProperties? properties,
  }) {
    return EventProjectUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventProjectUpdatedProperties properties;
}

@immutable
class EventProjectUpdatedProperties {
  const EventProjectUpdatedProperties({
    required this.id,
    required this.worktree,
    required this.vcs,
    required this.name,
    required this.icon,
    required this.commands,
    required this.time,
    required this.sandboxes,
  });

  factory EventProjectUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdatedProperties(
      id: json["id"] as String,
      worktree: json["worktree"] as String,
      vcs: json["vcs"] as String?,
      name: json["name"] as String?,
      icon: json["icon"] == null ? null : EventProjectUpdatedPropertiesIcon.fromJson(json["icon"] as Map<String, dynamic>),
      commands: json["commands"] == null ? null : EventProjectUpdatedPropertiesCommands.fromJson(json["commands"] as Map<String, dynamic>),
      time: EventProjectUpdatedPropertiesTime.fromJson(json["time"] as Map<String, dynamic>),
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventProjectUpdatedProperties copyWith({
    String? id,
    String? worktree,
    String? vcs,
    String? name,
    EventProjectUpdatedPropertiesIcon? icon,
    EventProjectUpdatedPropertiesCommands? commands,
    EventProjectUpdatedPropertiesTime? time,
    List<String>? sandboxes,
  }) {
    return EventProjectUpdatedProperties(
      id: id ?? this.id,
      worktree: worktree ?? this.worktree,
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
      (other is EventProjectUpdatedProperties &&
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
  final EventProjectUpdatedPropertiesIcon? icon;
  final EventProjectUpdatedPropertiesCommands? commands;
  final EventProjectUpdatedPropertiesTime time;
  final List<String> sandboxes;
}

@immutable
class EventProjectUpdatedPropertiesIcon {
  const EventProjectUpdatedPropertiesIcon({
    required this.url,
    required this.overrideValue,
    required this.color,
  });

  factory EventProjectUpdatedPropertiesIcon.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdatedPropertiesIcon(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventProjectUpdatedPropertiesIcon copyWith({
    String? url,
    String? overrideValue,
    String? color,
  }) {
    return EventProjectUpdatedPropertiesIcon(
      url: url ?? this.url,
      overrideValue: overrideValue ?? this.overrideValue,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectUpdatedPropertiesIcon &&
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
class EventProjectUpdatedPropertiesCommands {
  const EventProjectUpdatedPropertiesCommands({
    required this.start,
  });

  factory EventProjectUpdatedPropertiesCommands.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdatedPropertiesCommands(
      start: json["start"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "start": ?start,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventProjectUpdatedPropertiesCommands copyWith({
    String? start,
  }) {
    return EventProjectUpdatedPropertiesCommands(
      start: start ?? this.start,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectUpdatedPropertiesCommands &&
          other.start == start);

  @override
  int get hashCode => start.hashCode;

  final String? start;
}

@immutable
class EventProjectUpdatedPropertiesTime {
  const EventProjectUpdatedPropertiesTime({
    required this.created,
    required this.updated,
    required this.initialized,
  });

  factory EventProjectUpdatedPropertiesTime.fromJson(Map<String, dynamic> json) {
    return EventProjectUpdatedPropertiesTime(
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventProjectUpdatedPropertiesTime copyWith({
    int? created,
    int? updated,
    int? initialized,
  }) {
    return EventProjectUpdatedPropertiesTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      initialized: initialized ?? this.initialized,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventProjectUpdatedPropertiesTime &&
          other.created == created &&
          other.updated == updated &&
          other.initialized == initialized);

  @override
  int get hashCode => Object.hash(created, updated, initialized);

  final int created;
  final int updated;
  final int? initialized;
}
