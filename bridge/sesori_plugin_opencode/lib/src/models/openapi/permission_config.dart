// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.665742Z

import 'permission_action_config.dart';
import 'permission_rule_config.dart';

abstract interface class PermissionConfig {
  const PermissionConfig();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory PermissionConfig.fromJson(dynamic json) {
    if (json is String) {
      return permissionConfig00Inline.fromJson(json);
    }
    if (json is Map<String, dynamic>) {
      return permissionConfig01Inline.fromJson(json);
    }
    throw FormatException('Unknown PermissionConfig value: $json');
  }
}

class permissionConfig00Inline implements PermissionConfig {
  const permissionConfig00Inline({required this.value});
  factory permissionConfig00Inline.fromJson(String json) {
    return permissionConfig00Inline(value: PermissionActionConfig.fromJson(json));
  }
  @override
  dynamic toJson() => value.toJson();
  final PermissionActionConfig value;
}


class permissionConfig01Inline implements PermissionConfig {
  const permissionConfig01Inline({
    this.read,
    this.edit,
    this.glob,
    this.grep,
    this.list,
    this.bash,
    this.task,
    this.externalDirectory,
    this.todowrite,
    this.question,
    this.webfetch,
    this.websearch,
    this.lsp,
    this.doomLoop,
    this.skill,
  });

  factory permissionConfig01Inline.fromJson(Map<String, dynamic> json) {
    return permissionConfig01Inline(
      read: json["read"] == null ? null : PermissionRuleConfig.fromJson(json["read"]),
      edit: json["edit"] == null ? null : PermissionRuleConfig.fromJson(json["edit"]),
      glob: json["glob"] == null ? null : PermissionRuleConfig.fromJson(json["glob"]),
      grep: json["grep"] == null ? null : PermissionRuleConfig.fromJson(json["grep"]),
      list: json["list"] == null ? null : PermissionRuleConfig.fromJson(json["list"]),
      bash: json["bash"] == null ? null : PermissionRuleConfig.fromJson(json["bash"]),
      task: json["task"] == null ? null : PermissionRuleConfig.fromJson(json["task"]),
      externalDirectory: json["external_directory"] == null ? null : PermissionRuleConfig.fromJson(json["external_directory"]),
      todowrite: json["todowrite"] == null ? null : PermissionActionConfig.fromJson(json["todowrite"] as String),
      question: json["question"] == null ? null : PermissionActionConfig.fromJson(json["question"] as String),
      webfetch: json["webfetch"] == null ? null : PermissionActionConfig.fromJson(json["webfetch"] as String),
      websearch: json["websearch"] == null ? null : PermissionActionConfig.fromJson(json["websearch"] as String),
      lsp: json["lsp"] == null ? null : PermissionRuleConfig.fromJson(json["lsp"]),
      doomLoop: json["doom_loop"] == null ? null : PermissionActionConfig.fromJson(json["doom_loop"] as String),
      skill: json["skill"] == null ? null : PermissionRuleConfig.fromJson(json["skill"]),
    );
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{
      "read": read?.toJson(),
      "edit": edit?.toJson(),
      "glob": glob?.toJson(),
      "grep": grep?.toJson(),
      "list": list?.toJson(),
      "bash": bash?.toJson(),
      "task": task?.toJson(),
      "external_directory": externalDirectory?.toJson(),
      "todowrite": todowrite?.toJson(),
      "question": question?.toJson(),
      "webfetch": webfetch?.toJson(),
      "websearch": websearch?.toJson(),
      "lsp": lsp?.toJson(),
      "doom_loop": doomLoop?.toJson(),
      "skill": skill?.toJson(),
    };
  }

  final PermissionRuleConfig? read;
  final PermissionRuleConfig? edit;
  final PermissionRuleConfig? glob;
  final PermissionRuleConfig? grep;
  final PermissionRuleConfig? list;
  final PermissionRuleConfig? bash;
  final PermissionRuleConfig? task;
  final PermissionRuleConfig? externalDirectory;
  final PermissionActionConfig? todowrite;
  final PermissionActionConfig? question;
  final PermissionActionConfig? webfetch;
  final PermissionActionConfig? websearch;
  final PermissionRuleConfig? lsp;
  final PermissionActionConfig? doomLoop;
  final PermissionRuleConfig? skill;
}
