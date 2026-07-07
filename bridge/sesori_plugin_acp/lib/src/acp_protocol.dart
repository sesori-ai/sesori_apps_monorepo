/// Standard ACP (Agent Client Protocol) method names, request builders and
/// result parsers. Harness-specific extensions (e.g. Cursor's `cursor/*`
/// methods and model `configOptions`) live in the consuming package.
library;

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

part "acp_protocol.freezed.dart";
part "acp_protocol.g.dart";

/// The ACP protocol version this bridge implements.
const int acpProtocolVersion = 1;

/// Standard ACP JSON-RPC method names.
abstract final class AcpMethods {
  static const String initialize = "initialize";
  static const String authenticate = "authenticate";
  static const String sessionNew = "session/new";
  static const String sessionList = "session/list";
  static const String sessionLoad = "session/load";
  static const String sessionPrompt = "session/prompt";
  static const String sessionCancel = "session/cancel";
  static const String sessionUpdate = "session/update";
  static const String sessionRequestPermission = "session/request_permission";
  static const String sessionSetConfigOption = "session/set_config_option";
}

/// An auth method advertised by the agent in the `initialize` result.
class AcpAuthMethod {
  const AcpAuthMethod({required this.id, this.name, this.description});

  final String id;
  final String? name;
  final String? description;

  factory AcpAuthMethod.fromJson(Map<String, dynamic> json) => AcpAuthMethod(
    id: (json["id"] ?? "") as String,
    name: json["name"] as String?,
    description: json["description"] as String?,
  );
}

/// Capabilities the agent reports at `initialize`.
class AcpAgentCapabilities {
  const AcpAgentCapabilities({
    required this.loadSession,
    required this.listSessions,
    required this.raw,
  });

  /// Whether `session/load` (history replay) is supported.
  final bool loadSession;

  /// Whether the standard `session/list` is supported.
  final bool listSessions;

  /// Full raw capabilities object for harness-specific probing.
  final Map<String, dynamic> raw;

  factory AcpAgentCapabilities.fromJson(Map<String, dynamic> json) {
    final rawSession = json["sessionCapabilities"];
    final session = rawSession is Map ? rawSession.cast<String, dynamic>() : null;
    // ACP advertises an optional capability as either a bool or a nested
    // object (Cursor sends `"list": {}` to mean "supported"); presence of a
    // non-false value signals support.
    final list = session?["list"];
    return AcpAgentCapabilities(
      loadSession: json["loadSession"] == true,
      listSessions: list != null && list != false,
      raw: json,
    );
  }
}

/// Parsed result of the `initialize` handshake.
class AcpInitializeResult {
  const AcpInitializeResult({
    required this.protocolVersion,
    required this.agentCapabilities,
    required this.authMethods,
    required this.raw,
  });

  final int protocolVersion;
  final AcpAgentCapabilities agentCapabilities;
  final List<AcpAuthMethod> authMethods;
  final Map<String, dynamic> raw;

  /// True when the agent requires authentication before sessions can start.
  bool get requiresAuth => authMethods.isNotEmpty;

  factory AcpInitializeResult.fromJson(Map<String, dynamic> json) {
    final rawCaps = json["agentCapabilities"];
    final caps = rawCaps is Map ? rawCaps.cast<String, dynamic>() : const <String, dynamic>{};
    final rawMethods = json["authMethods"];
    final methods = rawMethods is List ? rawMethods : const <Object?>[];
    return AcpInitializeResult(
      protocolVersion: (json["protocolVersion"] ?? acpProtocolVersion) as int,
      agentCapabilities: AcpAgentCapabilities.fromJson(caps),
      authMethods: methods
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AcpAuthMethod.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false),
      raw: json,
    );
  }
}

/// Converts an ACP `updatedAt` value to epoch milliseconds: the spec sends an
/// ISO 8601 string, while live cursor-agent builds have shipped epoch
/// numbers — both are accepted, anything else is null.
class AcpTimestampMsConverter implements JsonConverter<int?, Object?> {
  const AcpTimestampMsConverter();

  @override
  int? fromJson(Object? json) {
    if (json is num) return json.round();
    if (json is String) return DateTime.tryParse(json)?.millisecondsSinceEpoch;
    return null;
  }

  @override
  Object? toJson(int? object) => object;
}

/// One entry of a `session/list` result.
@freezed
sealed class AcpSessionInfo with _$AcpSessionInfo {
  const factory AcpSessionInfo({
    @Default("") String sessionId,
    /// The session's working directory. Required by the spec, but kept
    /// nullable — a missing value falls back to the directory the caller
    /// scanned.
    required String? cwd,
    required String? title,
    /// Last-activity time in epoch milliseconds (see [AcpTimestampMsConverter]).
    @AcpTimestampMsConverter() @JsonKey(name: "updatedAt") required int? updatedAtMs,
  }) = _AcpSessionInfo;

  factory AcpSessionInfo.fromJson(Map<String, dynamic> json) => _$AcpSessionInfoFromJson(json);
}

/// Defensive parser for a `session/list` page's `sessions` array: a malformed
/// entry is logged and skipped so it cannot hide the page's valid sessions —
/// session enumeration is a fail-soft flow end to end.
List<AcpSessionInfo> _sessionInfosFromJson(Object? raw) {
  if (raw is! List) return const [];
  final infos = <AcpSessionInfo>[];
  for (final entry in raw) {
    if (entry is! Map) {
      Log.d("[acp] skipping non-object session/list entry: ${entry.runtimeType}");
      continue;
    }
    try {
      infos.add(AcpSessionInfo.fromJson(entry.cast<String, dynamic>()));
    } on Object catch (error) {
      Log.d("[acp] skipping malformed session/list entry: $error");
    }
  }
  return infos;
}

/// Parsed result of one `session/list` page.
@freezed
sealed class AcpSessionListResult with _$AcpSessionListResult {
  const factory AcpSessionListResult({
    @JsonKey(fromJson: _sessionInfosFromJson) @Default(<AcpSessionInfo>[]) List<AcpSessionInfo> sessions,
    /// Opaque continuation token — a non-empty value means more pages exist.
    required String? nextCursor,
  }) = _AcpSessionListResult;

  factory AcpSessionListResult.fromJson(Map<String, dynamic> json) => _$AcpSessionListResultFromJson(json);
}

/// Result of `session/new`.
class AcpNewSessionResult {
  const AcpNewSessionResult({
    required this.sessionId,
    required this.modes,
    required this.configOptions,
    required this.raw,
  });

  final String sessionId;

  /// Optional session modes (plan/ask/agent) — raw, harness-specific.
  final List<Map<String, dynamic>> modes;

  /// Optional config options (e.g. Cursor's model selector) — raw.
  final List<Map<String, dynamic>> configOptions;

  final Map<String, dynamic> raw;

  factory AcpNewSessionResult.fromJson(Map<String, dynamic> json) {
    return AcpNewSessionResult(
      sessionId: (json["sessionId"] ?? "") as String,
      modes: _mapList(json["modes"]),
      configOptions: _mapList(json["configOptions"]),
      raw: json,
    );
  }
}

/// Why a `session/prompt` turn ended.
enum AcpStopReason {
  endTurn,
  maxTokens,
  maxTurnRequests,
  refusal,
  cancelled,
  unknown;

  static AcpStopReason parse(Object? raw) {
    return switch (raw) {
      "end_turn" => AcpStopReason.endTurn,
      "max_tokens" => AcpStopReason.maxTokens,
      "max_turn_requests" => AcpStopReason.maxTurnRequests,
      "refusal" => AcpStopReason.refusal,
      "cancelled" => AcpStopReason.cancelled,
      _ => AcpStopReason.unknown,
    };
  }
}

/// Result of `session/prompt`.
class AcpPromptResult {
  const AcpPromptResult({required this.stopReason});

  final AcpStopReason stopReason;

  factory AcpPromptResult.fromJson(Map<String, dynamic> json) =>
      AcpPromptResult(stopReason: AcpStopReason.parse(json["stopReason"]));
}

/// Builds the `clientCapabilities` object sent at `initialize`.
///
/// [meta] carries non-standard capability hints under `_meta` (e.g. Cursor's
/// `parameterizedModelPicker`).
Map<String, dynamic> buildClientCapabilities({Map<String, dynamic>? meta}) {
  return <String, dynamic>{
    "fs": {"readTextFile": false, "writeTextFile": false},
    "terminal": false,
    "_meta": ?meta,
  };
}

/// Builds `initialize` params.
Map<String, dynamic> buildInitializeParams({
  required String clientName,
  required String clientVersion,
  String? clientTitle,
  Map<String, dynamic>? capabilityMeta,
}) {
  return <String, dynamic>{
    "protocolVersion": acpProtocolVersion,
    "clientCapabilities": buildClientCapabilities(meta: capabilityMeta),
    "clientInfo": {
      "name": clientName,
      "title": clientTitle,
      "version": clientVersion,
    },
  };
}

/// Builds a single text [ContentBlock] for a prompt.
Map<String, dynamic> textContentBlock(String text) =>
    <String, dynamic>{"type": "text", "text": text};

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((m) => m.cast<String, dynamic>())
      .toList(growable: false);
}
