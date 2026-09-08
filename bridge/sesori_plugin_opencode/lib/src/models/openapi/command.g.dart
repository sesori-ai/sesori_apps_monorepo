// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class Command {
  const Command({
    required this.name,
    required this.description,
    required this.agent,
    required this.model,
    required this.source,
    required this.template,
    required this.subtask,
    required this.hints,
    required this.provider,
  });

  factory Command.fromJson(Map<String, dynamic> json) {
    return Command(
      name: json["name"] as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] as String?,
      source: json["source"] == null ? null : CommandSource.fromJson(json["source"] as String),
      template: json["template"] is String ? json["template"] as String : null,
      subtask: json["subtask"] as bool?,
      hints: (json["hints"] as List<dynamic>).cast<String>(),
      provider: json["provider"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "description": ?description,
      "agent": ?agent,
      "model": ?model,
      "source": ?source?.toJson(),
      "template": template,
      "subtask": ?subtask,
      "hints": hints,
      "provider": ?provider,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  Command copyWith({
    String? name,
    String? description,
    String? agent,
    String? model,
    CommandSource? source,
    String? template,
    bool? subtask,
    List<String>? hints,
    String? provider,
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
      provider: provider ?? this.provider,
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
          const DeepCollectionEquality().equals(other.hints, hints) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(name, description, agent, model, source, template, subtask, const DeepCollectionEquality().hash(hints), provider);

  final String name;
  final String? description;
  final String? agent;
  final String? model;
  final CommandSource? source;
  final String? template;
  final bool? subtask;
  final List<String> hints;
  final String? provider;
}

enum CommandSource {
  @JsonValue("command")
  command,
  @JsonValue("mcp")
  mcp,
  @JsonValue("skill")
  skill,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static CommandSource fromJson(String value) {
    switch (value) {
      case "command":
        return CommandSource.command;
      case "mcp":
        return CommandSource.mcp;
      case "skill":
        return CommandSource.skill;
      default:
        return CommandSource.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case CommandSource.command:
        return "command";
      case CommandSource.mcp:
        return "mcp";
      case CommandSource.skill:
        return "skill";
      case CommandSource.unknown:
        return 'unknown';
    }
  }
}
