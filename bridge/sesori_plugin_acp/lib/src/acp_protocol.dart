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

/// The `clientInfo` identity every Sesori ACP connection (live plugin and
/// isolated scratch processes alike) reports at `initialize`.
const String acpClientName = "sesori-bridge";
const String acpClientVersion = "0.0.0";

/// Standard ACP JSON-RPC method names.
abstract final class AcpMethods() {
  static const String initialize = "initialize";
  static const String authenticate = "authenticate";
  static const String sessionNew = "session/new";
  static const String sessionList = "session/list";
  static const String sessionLoad = "session/load";
  static const String sessionResume = "session/resume";
  static const String sessionPrompt = "session/prompt";
  static const String sessionCancel = "session/cancel";
  static const String sessionClose = "session/close";
  static const String sessionUpdate = "session/update";
  static const String sessionRequestPermission = "session/request_permission";
  static const String sessionSetConfigOption = "session/set_config_option";
  static const String elicitationCreate = "elicitation/create";
}

/// An auth method advertised by the agent in the `initialize` result.
enum AcpAuthMethodType() {
  terminal,
  other,
}

class const AcpAuthMethod({
  required final String id,
  required final AcpAuthMethodType type,
  final String? name,
  final String? description,
}) {
  factory fromJson(Map<String, dynamic> json) => AcpAuthMethod(
    id: (json["id"] ?? "") as String,
    type: json["type"] == "terminal" ? AcpAuthMethodType.terminal : AcpAuthMethodType.other,
    name: json["name"] as String?,
    description: json["description"] as String?,
  );
}

/// MCP transports the agent reports at `initialize`.
class const AcpMcpCapabilities({
  required final bool http,
  required final bool sse,
}) {
  factory fromJson(Map<String, dynamic> json) => AcpMcpCapabilities(
    http: json["http"] == true,
    sse: json["sse"] == true,
  );
}

/// Capabilities the agent reports at `initialize`.
class const AcpAgentCapabilities({
  /// Whether `session/load` (history replay) is supported.
  required final bool loadSession,

  /// Whether the standard `session/list` is supported.
  required final bool listSessions,

  /// Whether `session/resume` (re-activate a prior session with no history
  /// replay) is supported. Used only when [loadSession] is absent — load is
  /// strictly richer.
  required final bool resumeSession,

  /// Whether `session/close` is supported.
  required final bool closeSession,

  /// MCP transports accepted in per-session `mcpServers` values.
  required final AcpMcpCapabilities mcpCapabilities,

  /// Full raw capabilities object for harness-specific probing.
  required final Map<String, dynamic> raw,
}) {
  factory fromJson(Map<String, dynamic> json) {
    final rawSession = json["sessionCapabilities"];
    final session = rawSession is Map ? rawSession.cast<String, dynamic>() : null;
    // ACP v1 advertises each optional session capability as an object. Reject
    // truthy lookalikes so security decisions never trust malformed metadata.
    final list = session?["list"];
    final resume = session?["resume"];
    final close = session?["close"];
    final rawMcp = json["mcpCapabilities"];
    final mcp = rawMcp is Map ? rawMcp.cast<String, dynamic>() : const <String, dynamic>{};
    return AcpAgentCapabilities(
      loadSession: json["loadSession"] == true,
      listSessions: list is Map,
      resumeSession: resume is Map,
      closeSession: close is Map,
      mcpCapabilities: AcpMcpCapabilities.fromJson(mcp),
      raw: json,
    );
  }
}

/// One HTTP header in an ACP HTTP MCP server definition.
class const AcpHttpHeader({required final String name, required final String value}) {
  Map<String, dynamic> toJson() => {"name": name, "value": value};

  @override
  String toString() => "AcpHttpHeader(<redacted>)";
}

/// Typed wire value accepted in `mcpServers` by ACP session activation calls.
class const AcpHttpMcpServer({
  required final String name,
  required final String url,
  required final List<AcpHttpHeader> headers,
}) {
  Map<String, dynamic> toJson() => {
    "type": "http",
    "name": name,
    "url": url,
    "headers": headers.map((header) => header.toJson()).toList(growable: false),
  };

  @override
  String toString() => "AcpHttpMcpServer(<redacted>)";
}

/// Parsed result of the `initialize` handshake.
class const AcpInitializeResult({
  required final int protocolVersion,
  required final AcpAgentCapabilities agentCapabilities,
  required final List<AcpAuthMethod> authMethods,
  required final Map<String, dynamic> raw,
}) {
  /// True when the agent requires authentication before sessions can start.
  bool get requiresAuth => authMethods.isNotEmpty;

  factory fromJson(Map<String, dynamic> json) {
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
class const AcpTimestampMsConverter() implements JsonConverter<int?, Object?> {
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
  const factory({
    @Default("") String sessionId,

    /// The session's working directory. Required by the spec, but kept
    /// nullable — a missing value falls back to the directory the caller
    /// scanned.
    required String? cwd,
    required String? title,
    @JsonKey(name: "_meta") @Default(null) Map<String, dynamic>? metadata,

    /// Last-activity time in epoch milliseconds (see [AcpTimestampMsConverter]).
    @AcpTimestampMsConverter() @JsonKey(name: "updatedAt") required int? updatedAtMs,
  }) = _AcpSessionInfo;

  factory fromJson(Map<String, dynamic> json) => _$AcpSessionInfoFromJson(json);
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
  const factory({
    @JsonKey(fromJson: _sessionInfosFromJson) @Default(<AcpSessionInfo>[]) List<AcpSessionInfo> sessions,

    /// Opaque continuation token — a non-empty value means more pages exist.
    required String? nextCursor,
  }) = _AcpSessionListResult;

  factory fromJson(Map<String, dynamic> json) => _$AcpSessionListResultFromJson(json);
}

/// Result of `session/new`.
class const AcpNewSessionResult({
  required final String sessionId,

  /// Optional session modes (plan/ask/agent) — raw, harness-specific.
  required final List<Map<String, dynamic>> modes,

  /// Optional config options (e.g. Cursor's model selector) — raw.
  required final List<Map<String, dynamic>> configOptions,
  required final Map<String, dynamic> raw,
}) {
  factory fromJson(Map<String, dynamic> json) {
    return AcpNewSessionResult(
      sessionId: (json["sessionId"] ?? "") as String,
      modes: _mapList(json["modes"]),
      configOptions: _mapList(json["configOptions"]),
      raw: json,
    );
  }
}

/// Why a `session/prompt` turn ended.
enum AcpStopReason() {
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
class const AcpPromptResult({required final AcpStopReason stopReason}) {
  factory fromJson(Map<String, dynamic> json) => AcpPromptResult(stopReason: AcpStopReason.parse(json["stopReason"]));
}

/// Builds the `clientCapabilities` object sent at `initialize`.
///
/// [meta] carries non-standard capability hints under `_meta` (e.g. Cursor's
/// `parameterizedModelPicker`).
Map<String, dynamic> buildClientCapabilities({
  required bool formElicitation,
  Map<String, dynamic>? meta,
}) {
  return <String, dynamic>{
    "fs": {"readTextFile": false, "writeTextFile": false},
    "terminal": false,
    if (formElicitation) "elicitation": {"form": <String, dynamic>{}},
    "_meta": ?meta,
  };
}

/// Builds `initialize` params. The client identity is fixed
/// ([acpClientName]/[acpClientVersion]); only the capabilities vary per agent.
Map<String, dynamic> buildInitializeParams({
  required bool formElicitation,
  required Map<String, dynamic>? capabilityMeta,
}) {
  return <String, dynamic>{
    "protocolVersion": acpProtocolVersion,
    "clientCapabilities": buildClientCapabilities(
      formElicitation: formElicitation,
      meta: capabilityMeta,
    ),
    "clientInfo": {
      "name": acpClientName,
      "version": acpClientVersion,
    },
  };
}

/// Builds a single text [ContentBlock] for a prompt.
Map<String, dynamic> textContentBlock(String text) => <String, dynamic>{"type": "text", "text": text};

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map<dynamic, dynamic>>().map((m) => m.cast<String, dynamic>()).toList(growable: false);
}
