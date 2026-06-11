// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class Command {
  const Command({
    this.name = '',
    this.description,
    this.agent,
    this.model,
    this.source,
    this.template = '',
    this.subtask,
    this.hints = const [],
  });

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      name: (json["name"] ?? '') as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] as String?,
      source: json["source"] as String?,
      template: (json["template"] ?? '') as String,
      subtask: json["subtask"] as bool?,
      hints: ((json["hints"] ?? const []) as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": ?description,
      "agent": ?agent,
      "model": ?model,
      "source": ?source,
      "template": template,
      "subtask": ?subtask,
      "hints": hints,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Command copyWith({
    String? name,
    String? description,
    String? agent,
    String? model,
    String? source,
    String? template,
    bool? subtask,
    List<String>? hints,
  }) {
    return Command(
      name: name ?? this.name,
      description: description ?? this.description,
      agent: agent ?? this.agent,
      model: model ?? this.model,
      source: source ?? this.source,
      template: template ?? this.template,
      subtask: subtask ?? this.subtask,
      hints: hints ?? this.hints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Command &&
          other.name == name &&
          other.description == description &&
          other.agent == agent &&
          other.model == model &&
          other.source == source &&
          other.template == template &&
          other.subtask == subtask &&
          const DeepCollectionEquality().equals(other.hints, hints));

  @override
  int get hashCode => Object.hash(name, description, agent, model, source, template, subtask, const DeepCollectionEquality().hash(hints));

  final String name;
  final String? description;
  final String? agent;
  final String? model;
  final String? source;
  final String template;
  final bool? subtask;
  final List<String> hints;
}
