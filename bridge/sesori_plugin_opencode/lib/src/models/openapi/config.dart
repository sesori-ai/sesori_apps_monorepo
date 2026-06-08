// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.321357Z

import 'agent_config.dart';
import 'attachment_config.dart';
import 'layout_config.dart';
import 'log_level.dart';
import 'permission_config.dart';
import 'provider_config.dart';
import 'reference_config.dart';
import 'server_config.dart';

class Config {
  const Config({
    this.schema,
    this.shell,
    this.logLevel,
    this.server,
    this.command,
    this.skills,
    this.reference,
    this.watcher,
    this.snapshot,
    this.plugin,
    this.share,
    this.autoshare,
    this.autoupdate,
    this.disabledProviders,
    this.enabledProviders,
    this.model,
    this.smallModel,
    this.defaultAgent,
    this.username,
    this.mode,
    this.agent,
    this.provider,
    this.mcp,
    this.formatter,
    this.lsp,
    this.instructions,
    this.layout,
    this.permission,
    this.tools,
    this.attachment,
    this.enterprise,
    this.toolOutput,
    this.compaction,
    this.experimental,
  });

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      schema: json[r"$schema"] as String?,
      shell: json["shell"] as String?,
      logLevel: json["logLevel"] == null ? null : LogLevel.fromJson(json["logLevel"] as String),
      server: json["server"] == null ? null : ServerConfig.fromJson(json["server"] as Map<String, dynamic>),
      command: (json["command"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
      skills: json["skills"] as Map<String, dynamic>?,
      reference: json["reference"] == null ? null : ReferenceConfig.fromJson(json["reference"] as Map<String, dynamic>),
      watcher: json["watcher"] as Map<String, dynamic>?,
      snapshot: json["snapshot"] as bool?,
      plugin: (json["plugin"] as List<dynamic>?)?.cast<Object>(),
      share: json["share"] as String?,
      autoshare: json["autoshare"] as bool?,
      autoupdate: json["autoupdate"] as Object?,
      disabledProviders: (json["disabled_providers"] as List<dynamic>?)?.cast<String>(),
      enabledProviders: (json["enabled_providers"] as List<dynamic>?)?.cast<String>(),
      model: json["model"] as String?,
      smallModel: json["small_model"] as String?,
      defaultAgent: json["default_agent"] as String?,
      username: json["username"] as String?,
      mode: (json["mode"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, AgentConfig.fromJson(v as Map<String, dynamic>))),
      agent: (json["agent"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, AgentConfig.fromJson(v as Map<String, dynamic>))),
      provider: (json["provider"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ProviderConfig.fromJson(v as Map<String, dynamic>))),
      mcp: (json["mcp"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Object)),
      formatter: json["formatter"] as Object?,
      lsp: json["lsp"] as Object?,
      instructions: (json["instructions"] as List<dynamic>?)?.cast<String>(),
      layout: json["layout"] == null ? null : LayoutConfig.fromJson(json["layout"] as String),
      permission: json["permission"] == null ? null : PermissionConfig.fromJson(json["permission"]),
      tools: (json["tools"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
      attachment: json["attachment"] == null ? null : AttachmentConfig.fromJson(json["attachment"] as Map<String, dynamic>),
      enterprise: json["enterprise"] as Map<String, dynamic>?,
      toolOutput: json["tool_output"] as Map<String, dynamic>?,
      compaction: json["compaction"] as Map<String, dynamic>?,
      experimental: json["experimental"] as Map<String, dynamic>?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      r"$schema": ?schema,
      "shell": ?shell,
      "logLevel": ?logLevel?.toJson(),
      "server": ?server?.toJson(),
      "command": ?command,
      "skills": ?skills,
      "reference": ?reference?.toJson(),
      "watcher": ?watcher,
      "snapshot": ?snapshot,
      "plugin": ?plugin,
      "share": ?share,
      "autoshare": ?autoshare,
      "autoupdate": ?autoupdate,
      "disabled_providers": ?disabledProviders,
      "enabled_providers": ?enabledProviders,
      "model": ?model,
      "small_model": ?smallModel,
      "default_agent": ?defaultAgent,
      "username": ?username,
      "mode": ?mode?.map((k, v) => MapEntry(k, v.toJson())),
      "agent": ?agent?.map((k, v) => MapEntry(k, v.toJson())),
      "provider": ?provider?.map((k, v) => MapEntry(k, v.toJson())),
      "mcp": ?mcp,
      "formatter": ?formatter,
      "lsp": ?lsp,
      "instructions": ?instructions,
      "layout": ?layout?.toJson(),
      "permission": ?permission?.toJson(),
      "tools": ?tools,
      "attachment": ?attachment?.toJson(),
      "enterprise": ?enterprise,
      "tool_output": ?toolOutput,
      "compaction": ?compaction,
      "experimental": ?experimental,
    };
  }

  final String? schema;
  final String? shell;
  final LogLevel? logLevel;
  final ServerConfig? server;
  final Map<String, Map<String, dynamic>>? command;
  final Map<String, dynamic>? skills;
  final ReferenceConfig? reference;
  final Map<String, dynamic>? watcher;
  final bool? snapshot;
  final List<Object>? plugin;
  final String? share;
  final bool? autoshare;
  final Object? autoupdate;
  final List<String>? disabledProviders;
  final List<String>? enabledProviders;
  final String? model;
  final String? smallModel;
  final String? defaultAgent;
  final String? username;
  final Map<String, AgentConfig>? mode;
  final Map<String, AgentConfig>? agent;
  final Map<String, ProviderConfig>? provider;
  final Map<String, Object>? mcp;
  final Object? formatter;
  final Object? lsp;
  final List<String>? instructions;
  final LayoutConfig? layout;
  final PermissionConfig? permission;
  final Map<String, bool>? tools;
  final AttachmentConfig? attachment;
  final Map<String, dynamic>? enterprise;
  final Map<String, dynamic>? toolOutput;
  final Map<String, dynamic>? compaction;
  final Map<String, dynamic>? experimental;
}
