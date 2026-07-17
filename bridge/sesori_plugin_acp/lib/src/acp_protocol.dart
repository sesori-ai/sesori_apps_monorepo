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
  static const String sessionResume = "session/resume";
  static const String sessionPrompt = "session/prompt";
  static const String sessionCancel = "session/cancel";
  static const String sessionUpdate = "session/update";
  static const String sessionRequestPermission = "session/request_permission";
  static const String sessionSetConfigOption = "session/set_config_option";
}

/// A JSON-RPC error returned by an ACP agent.
class AcpRpcException implements Exception {
  AcpRpcException({
    required this.method,
    required this.code,
    required this.message,
    this.data,
  });

  final String method;
  final int code;
  final String message;
  final Object? data;

  @override
  String toString() => "AcpRpcException($method, code=$code, $message)";
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
    required this.resumeSession,
  });

  /// Whether `session/load` (history replay) is supported.
  final bool loadSession;

  /// Whether the standard `session/list` is supported.
  final bool listSessions;

  /// Whether `session/resume` (re-activate a prior session with no history
  /// replay) is supported. Used only when [loadSession] is absent — load is
  /// strictly richer.
  final bool resumeSession;

  factory AcpAgentCapabilities.fromJson(Map<String, dynamic> json) {
    final rawSession = json["sessionCapabilities"];
    final session = rawSession is Map ? rawSession.cast<String, dynamic>() : null;
    // ACP advertises an optional capability as either a bool or a nested
    // object (Cursor sends `"list": {}` to mean "supported"); presence of a
    // non-false value signals support.
    final list = session?["list"];
    final resume = session?["resume"];
    return AcpAgentCapabilities(
      loadSession: json["loadSession"] == true,
      listSessions: list != null && list != false,
      resumeSession: resume != null && resume != false,
    );
  }
}

/// Parsed result of the `initialize` handshake.
class AcpInitializeResult {
  const AcpInitializeResult({
    required this.protocolVersion,
    required this.agentCapabilities,
    required this.authMethods,
  });

  final int protocolVersion;
  final AcpAgentCapabilities agentCapabilities;
  final List<AcpAuthMethod> authMethods;

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
    );
  }
}

/// Typed values needed to initialize one ACP connection.
class AcpInitializeRequest {
  const AcpInitializeRequest({
    required this.clientName,
    required this.clientVersion,
    required this.clientTitle,
    required this.capabilityMeta,
  });

  final String clientName;
  final String clientVersion;
  final String? clientTitle;

  /// Harness-specific capability extension values sent under `_meta`.
  final Map<String, dynamic>? capabilityMeta;
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

/// One selectable value in an ACP session config option. Group entries use
/// [options], while leaf entries use [value].
class AcpConfigOptionValue {
  AcpConfigOptionValue({
    required this.value,
    required this.name,
    required this.description,
    required List<AcpConfigOptionValue> options,
  }) : options = List.unmodifiable(options);

  final String? value;
  final String? name;
  final String? description;
  final List<AcpConfigOptionValue> options;

  factory AcpConfigOptionValue.fromJson(Map<String, dynamic> json) {
    final rawOptions = json["options"];
    return AcpConfigOptionValue(
      value: json["value"] is String ? json["value"] as String : null,
      name: json["name"] is String ? json["name"] as String : null,
      description: json["description"] is String ? json["description"] as String : null,
      options: rawOptions is List
          ? rawOptions
                .whereType<Map<dynamic, dynamic>>()
                .map((option) => AcpConfigOptionValue.fromJson(option.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// A typed ACP session config option, including Cursor's model/mode/thought
/// extensions.
class AcpConfigOption {
  AcpConfigOption({
    required this.id,
    required this.category,
    required this.currentValue,
    required this.value,
    required List<AcpConfigOptionValue> options,
  }) : options = List.unmodifiable(options);

  final String? id;
  final String? category;
  final String? currentValue;
  final String? value;
  final List<AcpConfigOptionValue> options;

  factory AcpConfigOption.fromJson(Map<String, dynamic> json) {
    final rawOptions = json["options"];
    return AcpConfigOption(
      id: json["id"] is String ? json["id"] as String : null,
      category: json["category"] is String ? json["category"] as String : null,
      currentValue: json["currentValue"] is String ? json["currentValue"] as String : null,
      value: json["value"] is String ? json["value"] as String : null,
      options: rawOptions is List
          ? rawOptions
                .whereType<Map<dynamic, dynamic>>()
                .map((option) => AcpConfigOptionValue.fromJson(option.cast<String, dynamic>()))
                .toList(growable: false)
          : const [],
    );
  }
}

/// Result of `session/new`, `session/load`, `session/resume`, and
/// `session/set_config_option`.
class AcpNewSessionResult {
  const AcpNewSessionResult({
    required this.sessionId,
    required this.configOptions,
  });

  final String sessionId;

  /// Optional config options (e.g. Cursor's model selector).
  final List<AcpConfigOption> configOptions;

  factory AcpNewSessionResult.fromJson(Map<String, dynamic> json) {
    return AcpNewSessionResult(
      sessionId: (json["sessionId"] ?? "") as String,
      configOptions: _configOptionsFromJson(json["configOptions"]),
    );
  }
}

/// A typed ACP prompt content block. Serialization stays inside [AcpApi].
sealed class AcpContentBlock {
  const AcpContentBlock();
}

class AcpTextContentBlock extends AcpContentBlock {
  const AcpTextContentBlock({required this.text});

  final String text;
}

class AcpResourceLinkContentBlock extends AcpContentBlock {
  const AcpResourceLinkContentBlock({required this.uri, required this.name});

  final String uri;
  final String name;
}

enum AcpInlineContentType { image, audio }

class AcpInlineContentBlock extends AcpContentBlock {
  const AcpInlineContentBlock({
    required this.type,
    required this.mimeType,
    required this.data,
  });

  final AcpInlineContentType type;
  final String mimeType;
  final String data;
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

List<AcpConfigOption> _configOptionsFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((option) => AcpConfigOption.fromJson(option.cast<String, dynamic>()))
      .toList(growable: false);
}
