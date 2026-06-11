// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'agent_config.dart';
import 'attachment_config.dart';
import 'config_v2_experimental_policy.dart';
import 'layout_config.dart';
import 'log_level.dart';
import 'permission_config.dart';
import 'provider_config.dart';
import 'reference_config.dart';
import 'server_config.dart';

@immutable
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
      command: (json["command"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ConfigCommandValue.fromJson(v as Map<String, dynamic>))),
      skills: json["skills"] == null ? null : ConfigSkills.fromJson(json["skills"] as Map<String, dynamic>),
      reference: json["reference"] == null ? null : ReferenceConfig.fromJson(json["reference"] as Map<String, dynamic>),
      watcher: json["watcher"] == null ? null : ConfigWatcher.fromJson(json["watcher"] as Map<String, dynamic>),
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
      mode: json["mode"] == null ? null : ConfigMode.fromJson(json["mode"] as Map<String, dynamic>),
      agent: json["agent"] == null ? null : ConfigAgent.fromJson(json["agent"] as Map<String, dynamic>),
      provider: (json["provider"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, ProviderConfig.fromJson(v as Map<String, dynamic>))),
      mcp: (json["mcp"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Object)),
      formatter: json["formatter"] as Object?,
      lsp: json["lsp"] as Object?,
      instructions: (json["instructions"] as List<dynamic>?)?.cast<String>(),
      layout: json["layout"] == null ? null : LayoutConfig.fromJson(json["layout"] as String),
      permission: json["permission"] == null ? null : PermissionConfig.fromJson(json["permission"] as Object),
      tools: (json["tools"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as bool)),
      attachment: json["attachment"] == null ? null : AttachmentConfig.fromJson(json["attachment"] as Map<String, dynamic>),
      enterprise: json["enterprise"] == null ? null : ConfigEnterprise.fromJson(json["enterprise"] as Map<String, dynamic>),
      toolOutput: json["tool_output"] == null ? null : ConfigToolOutput.fromJson(json["tool_output"] as Map<String, dynamic>),
      compaction: json["compaction"] == null ? null : ConfigCompaction.fromJson(json["compaction"] as Map<String, dynamic>),
      experimental: json["experimental"] == null ? null : ConfigExperimental.fromJson(json["experimental"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      r"$schema": ?schema,
      "shell": ?shell,
      "logLevel": ?logLevel?.toJson(),
      "server": ?server?.toJson(),
      "command": ?command?.map((k, v) => MapEntry(k, v.toJson())),
      "skills": ?skills?.toJson(),
      "reference": ?reference?.toJson(),
      "watcher": ?watcher?.toJson(),
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
      "mode": ?mode?.toJson(),
      "agent": ?agent?.toJson(),
      "provider": ?provider?.map((k, v) => MapEntry(k, v.toJson())),
      "mcp": ?mcp,
      "formatter": ?formatter,
      "lsp": ?lsp,
      "instructions": ?instructions,
      "layout": ?layout?.toJson(),
      "permission": ?permission?.toJson(),
      "tools": ?tools,
      "attachment": ?attachment?.toJson(),
      "enterprise": ?enterprise?.toJson(),
      "tool_output": ?toolOutput?.toJson(),
      "compaction": ?compaction?.toJson(),
      "experimental": ?experimental?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Config &&
          other.schema == schema &&
          other.shell == shell &&
          other.logLevel == logLevel &&
          other.server == server &&
          const DeepCollectionEquality().equals(other.command, command) &&
          other.skills == skills &&
          other.reference == reference &&
          other.watcher == watcher &&
          other.snapshot == snapshot &&
          const DeepCollectionEquality().equals(other.plugin, plugin) &&
          other.share == share &&
          other.autoshare == autoshare &&
          const DeepCollectionEquality().equals(other.autoupdate, autoupdate) &&
          const DeepCollectionEquality().equals(other.disabledProviders, disabledProviders) &&
          const DeepCollectionEquality().equals(other.enabledProviders, enabledProviders) &&
          other.model == model &&
          other.smallModel == smallModel &&
          other.defaultAgent == defaultAgent &&
          other.username == username &&
          other.mode == mode &&
          other.agent == agent &&
          const DeepCollectionEquality().equals(other.provider, provider) &&
          const DeepCollectionEquality().equals(other.mcp, mcp) &&
          const DeepCollectionEquality().equals(other.formatter, formatter) &&
          const DeepCollectionEquality().equals(other.lsp, lsp) &&
          const DeepCollectionEquality().equals(other.instructions, instructions) &&
          other.layout == layout &&
          other.permission == permission &&
          const DeepCollectionEquality().equals(other.tools, tools) &&
          other.attachment == attachment &&
          other.enterprise == enterprise &&
          other.toolOutput == toolOutput &&
          other.compaction == compaction &&
          other.experimental == experimental);

  @override
  int get hashCode => Object.hashAll([schema, shell, logLevel, server, const DeepCollectionEquality().hash(command), skills, reference, watcher, snapshot, const DeepCollectionEquality().hash(plugin), share, autoshare, const DeepCollectionEquality().hash(autoupdate), const DeepCollectionEquality().hash(disabledProviders), const DeepCollectionEquality().hash(enabledProviders), model, smallModel, defaultAgent, username, mode, agent, const DeepCollectionEquality().hash(provider), const DeepCollectionEquality().hash(mcp), const DeepCollectionEquality().hash(formatter), const DeepCollectionEquality().hash(lsp), const DeepCollectionEquality().hash(instructions), layout, permission, const DeepCollectionEquality().hash(tools), attachment, enterprise, toolOutput, compaction, experimental]);

  final String? schema;
  final String? shell;
  final LogLevel? logLevel;
  final ServerConfig? server;
  final Map<String, ConfigCommandValue>? command;
  final ConfigSkills? skills;
  final ReferenceConfig? reference;
  final ConfigWatcher? watcher;
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
  final ConfigMode? mode;
  final ConfigAgent? agent;
  final Map<String, ProviderConfig>? provider;
  final Map<String, Object>? mcp;
  final Object? formatter;
  final Object? lsp;
  final List<String>? instructions;
  final LayoutConfig? layout;
  final PermissionConfig? permission;
  final Map<String, bool>? tools;
  final AttachmentConfig? attachment;
  final ConfigEnterprise? enterprise;
  final ConfigToolOutput? toolOutput;
  final ConfigCompaction? compaction;
  final ConfigExperimental? experimental;
}

@immutable
class ConfigCommandValue {
  const ConfigCommandValue({
    required this.template,
    this.description,
    this.agent,
    this.model,
    this.variant,
    this.subtask,
  });

  factory ConfigCommandValue.fromJson(Map<String, dynamic> json) {
    return ConfigCommandValue(
      template: json["template"] as String,
      description: json["description"] as String?,
      agent: json["agent"] as String?,
      model: json["model"] as String?,
      variant: json["variant"] as String?,
      subtask: json["subtask"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "template": template,
      "description": ?description,
      "agent": ?agent,
      "model": ?model,
      "variant": ?variant,
      "subtask": ?subtask,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigCommandValue &&
          other.template == template &&
          other.description == description &&
          other.agent == agent &&
          other.model == model &&
          other.variant == variant &&
          other.subtask == subtask);

  @override
  int get hashCode => Object.hash(template, description, agent, model, variant, subtask);

  final String template;
  final String? description;
  final String? agent;
  final String? model;
  final String? variant;
  final bool? subtask;
}

@immutable
class ConfigSkills {
  const ConfigSkills({
    this.paths,
    this.urls,
  });

  factory ConfigSkills.fromJson(Map<String, dynamic> json) {
    return ConfigSkills(
      paths: (json["paths"] as List<dynamic>?)?.cast<String>(),
      urls: (json["urls"] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "paths": ?paths,
      "urls": ?urls,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigSkills &&
          const DeepCollectionEquality().equals(other.paths, paths) &&
          const DeepCollectionEquality().equals(other.urls, urls));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(paths), const DeepCollectionEquality().hash(urls));

  final List<String>? paths;
  final List<String>? urls;
}

@immutable
class ConfigWatcher {
  const ConfigWatcher({
    this.ignore,
  });

  factory ConfigWatcher.fromJson(Map<String, dynamic> json) {
    return ConfigWatcher(
      ignore: (json["ignore"] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "ignore": ?ignore,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigWatcher &&
          const DeepCollectionEquality().equals(other.ignore, ignore));

  @override
  int get hashCode => const DeepCollectionEquality().hash(ignore);

  final List<String>? ignore;
}

@immutable
class ConfigMode {
  const ConfigMode({
    this.build,
    this.plan,
  });

  factory ConfigMode.fromJson(Map<String, dynamic> json) {
    return ConfigMode(
      build: json["build"] == null ? null : AgentConfig.fromJson(json["build"] as Map<String, dynamic>),
      plan: json["plan"] == null ? null : AgentConfig.fromJson(json["plan"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "build": ?build?.toJson(),
      "plan": ?plan?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigMode &&
          other.build == build &&
          other.plan == plan);

  @override
  int get hashCode => Object.hash(build, plan);

  final AgentConfig? build;
  final AgentConfig? plan;
}

@immutable
class ConfigAgent {
  const ConfigAgent({
    this.plan,
    this.build,
    this.general,
    this.explore,
    this.title,
    this.summary,
    this.compaction,
  });

  factory ConfigAgent.fromJson(Map<String, dynamic> json) {
    return ConfigAgent(
      plan: json["plan"] == null ? null : AgentConfig.fromJson(json["plan"] as Map<String, dynamic>),
      build: json["build"] == null ? null : AgentConfig.fromJson(json["build"] as Map<String, dynamic>),
      general: json["general"] == null ? null : AgentConfig.fromJson(json["general"] as Map<String, dynamic>),
      explore: json["explore"] == null ? null : AgentConfig.fromJson(json["explore"] as Map<String, dynamic>),
      title: json["title"] == null ? null : AgentConfig.fromJson(json["title"] as Map<String, dynamic>),
      summary: json["summary"] == null ? null : AgentConfig.fromJson(json["summary"] as Map<String, dynamic>),
      compaction: json["compaction"] == null ? null : AgentConfig.fromJson(json["compaction"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "plan": ?plan?.toJson(),
      "build": ?build?.toJson(),
      "general": ?general?.toJson(),
      "explore": ?explore?.toJson(),
      "title": ?title?.toJson(),
      "summary": ?summary?.toJson(),
      "compaction": ?compaction?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigAgent &&
          other.plan == plan &&
          other.build == build &&
          other.general == general &&
          other.explore == explore &&
          other.title == title &&
          other.summary == summary &&
          other.compaction == compaction);

  @override
  int get hashCode => Object.hash(plan, build, general, explore, title, summary, compaction);

  final AgentConfig? plan;
  final AgentConfig? build;
  final AgentConfig? general;
  final AgentConfig? explore;
  final AgentConfig? title;
  final AgentConfig? summary;
  final AgentConfig? compaction;
}

@immutable
class ConfigEnterprise {
  const ConfigEnterprise({
    this.url,
  });

  factory ConfigEnterprise.fromJson(Map<String, dynamic> json) {
    return ConfigEnterprise(
      url: json["url"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": ?url,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigEnterprise &&
          other.url == url);

  @override
  int get hashCode => url.hashCode;

  final String? url;
}

@immutable
class ConfigToolOutput {
  const ConfigToolOutput({
    this.maxLines,
    this.maxBytes,
  });

  factory ConfigToolOutput.fromJson(Map<String, dynamic> json) {
    return ConfigToolOutput(
      maxLines: (json["max_lines"] as num?)?.toInt(),
      maxBytes: (json["max_bytes"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "max_lines": ?maxLines,
      "max_bytes": ?maxBytes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigToolOutput &&
          other.maxLines == maxLines &&
          other.maxBytes == maxBytes);

  @override
  int get hashCode => Object.hash(maxLines, maxBytes);

  final int? maxLines;
  final int? maxBytes;
}

@immutable
class ConfigCompaction {
  const ConfigCompaction({
    this.auto,
    this.prune,
    this.tailTurns,
    this.preserveRecentTokens,
    this.reserved,
  });

  factory ConfigCompaction.fromJson(Map<String, dynamic> json) {
    return ConfigCompaction(
      auto: json["auto"] as bool?,
      prune: json["prune"] as bool?,
      tailTurns: (json["tail_turns"] as num?)?.toInt(),
      preserveRecentTokens: (json["preserve_recent_tokens"] as num?)?.toInt(),
      reserved: (json["reserved"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "auto": ?auto,
      "prune": ?prune,
      "tail_turns": ?tailTurns,
      "preserve_recent_tokens": ?preserveRecentTokens,
      "reserved": ?reserved,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigCompaction &&
          other.auto == auto &&
          other.prune == prune &&
          other.tailTurns == tailTurns &&
          other.preserveRecentTokens == preserveRecentTokens &&
          other.reserved == reserved);

  @override
  int get hashCode => Object.hash(auto, prune, tailTurns, preserveRecentTokens, reserved);

  final bool? auto;
  final bool? prune;
  final int? tailTurns;
  final int? preserveRecentTokens;
  final int? reserved;
}

@immutable
class ConfigExperimental {
  const ConfigExperimental({
    this.disablePasteSummary,
    this.batchTool,
    this.openTelemetry,
    this.primaryTools,
    this.continueLoopOnDeny,
    this.mcpTimeout,
    this.policies,
  });

  factory ConfigExperimental.fromJson(Map<String, dynamic> json) {
    return ConfigExperimental(
      disablePasteSummary: json["disable_paste_summary"] as bool?,
      batchTool: json["batch_tool"] as bool?,
      openTelemetry: json["openTelemetry"] as bool?,
      primaryTools: (json["primary_tools"] as List<dynamic>?)?.cast<String>(),
      continueLoopOnDeny: json["continue_loop_on_deny"] as bool?,
      mcpTimeout: (json["mcp_timeout"] as num?)?.toInt(),
      policies: (json["policies"] as List<dynamic>?)?.map((e) => ConfigV2ExperimentalPolicy.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "disable_paste_summary": ?disablePasteSummary,
      "batch_tool": ?batchTool,
      "openTelemetry": ?openTelemetry,
      "primary_tools": ?primaryTools,
      "continue_loop_on_deny": ?continueLoopOnDeny,
      "mcp_timeout": ?mcpTimeout,
      "policies": ?policies?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigExperimental &&
          other.disablePasteSummary == disablePasteSummary &&
          other.batchTool == batchTool &&
          other.openTelemetry == openTelemetry &&
          const DeepCollectionEquality().equals(other.primaryTools, primaryTools) &&
          other.continueLoopOnDeny == continueLoopOnDeny &&
          other.mcpTimeout == mcpTimeout &&
          const DeepCollectionEquality().equals(other.policies, policies));

  @override
  int get hashCode => Object.hash(disablePasteSummary, batchTool, openTelemetry, const DeepCollectionEquality().hash(primaryTools), continueLoopOnDeny, mcpTimeout, const DeepCollectionEquality().hash(policies));

  final bool? disablePasteSummary;
  final bool? batchTool;
  final bool? openTelemetry;
  final List<String>? primaryTools;
  final bool? continueLoopOnDeny;
  final int? mcpTimeout;
  final List<ConfigV2ExperimentalPolicy>? policies;
}
