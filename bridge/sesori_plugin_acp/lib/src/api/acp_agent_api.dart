import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginAuthenticationRequiredException;

import "../acp_protocol.dart";
import "../acp_stdio_client.dart";

/// Typed standard-ACP requests over one connected [AcpStdioClient].
///
/// Owns the wire shape of every standard `initialize`/`authenticate`/
/// `session/*` request and the parsing of its result, so the live plugin and
/// the per-harness scratch processes (catalog discovery, persisted cleanup)
/// speak the protocol identically instead of each re-encoding params and
/// re-parsing results. Harness extensions (`cursor/*`, Hermes's
/// `session/set_model`) go straight to [client].
///
/// `session/prompt` is deliberately absent: the live plugin drives it through
/// [AcpStdioClient.dispatchRequest] to separate frame delivery from the turn
/// result, which no other caller needs.
class AcpAgentApi({required final AcpStdioClient client}) {
  /// Per-request budget for a live (non-scratch) connection — the same value
  /// [AcpStdioClient.request] defaults to. Callers with their own deadline
  /// (scratch catalog/cleanup leases) pass their remaining budget instead.
  static const Duration defaultRequestTimeout = Duration(seconds: 60);

  /// Runs the ACP `initialize` handshake and, when the agent advertises auth
  /// methods, `authenticate` — both within one [timeout] deadline, so a caller
  /// with a remaining budget (the scratch catalog/cleanup leases) cannot
  /// overrun it by a second full timeout on the auth round trip.
  ///
  /// [authMethodId] names the method to authenticate with. When it is `null`,
  /// the first advertised non-terminal method allowed by [authMethodAllowlist]
  /// is selected. A `null` allowlist preserves the unrestricted stock behavior.
  ///
  /// Throws [StateError] when the agent negotiates a protocol version other
  /// than v1 (it could not understand our v1-shaped `session/*` calls),
  /// [PluginAuthenticationRequiredException] when no usable auth method exists
  /// or the agent rejects authentication, and [TimeoutException] when the
  /// deadline passes.
  Future<AcpInitializeResult> initialize({
    required bool formElicitation,
    required Map<String, dynamic>? capabilityMeta,
    required String? authMethodId,
    required Set<String>? authMethodAllowlist,
    required Duration timeout,
  }) async {
    final deadline = Stopwatch()..start();
    final raw = await client.request(
      method: AcpMethods.initialize,
      params: buildInitializeParams(
        formElicitation: formElicitation,
        capabilityMeta: capabilityMeta,
      ),
      timeout: timeout,
    );
    final init = AcpInitializeResult.fromJson(_asJson(raw));
    // A missing version parses as v1, so agents that omit the field (some
    // cursor-agent builds) still connect.
    if (init.protocolVersion != acpProtocolVersion) {
      throw StateError(
        "ACP agent negotiated protocol version ${init.protocolVersion}, "
        "but this client only speaks v$acpProtocolVersion",
      );
    }
    if (!init.requiresAuth) return init;
    final methodId = authMethodId ?? _firstNonTerminalAuthMethod(init: init, allowlist: authMethodAllowlist);
    if (methodId == null) {
      throw PluginAuthenticationRequiredException(
        AcpMethods.authenticate,
        actionHint: "Authenticate the configured agent locally, then retry.",
        message: "${client.logTag} requires an authentication method the bridge cannot complete",
      );
    }
    final remaining = timeout - deadline.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("${client.logTag} initialize handshake exceeded its deadline before authenticate");
    }
    try {
      await client.request(
        method: AcpMethods.authenticate,
        params: {"methodId": methodId},
        timeout: remaining,
      );
    } on AcpRpcException catch (error) {
      if (error.method != "<response>") rethrow;
      throw PluginAuthenticationRequiredException(
        AcpMethods.authenticate,
        actionHint: "Authenticate the configured agent locally, then retry.",
        message: "${client.logTag} authentication failed",
        cause: error,
      );
    }
    return init;
  }

  /// `session/new` in [cwd]. Throws [StateError] when the agent answers
  /// without a session id, since nothing can be done with such a session.
  Future<AcpNewSessionResult> newSession({
    required String cwd,
    required Duration timeout,
  }) async {
    final raw = await client.request(
      method: AcpMethods.sessionNew,
      params: _sessionActivationParams(cwd: cwd),
      timeout: timeout,
    );
    final session = AcpNewSessionResult.fromJson(_asJson(raw));
    if (session.sessionId.isEmpty) {
      throw StateError("session/new response missing sessionId");
    }
    return session;
  }

  /// `session/load` — re-activates [sessionId] with history replay. Throws
  /// [StateError] on a non-object result: the session's modes/config catalog
  /// rides in that object, and a null/void answer is treated as a failed load
  /// (the caller decides whether to retry).
  Future<AcpNewSessionResult> loadSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) => _activateSession(method: AcpMethods.sessionLoad, sessionId: sessionId, cwd: cwd, timeout: timeout);

  /// `session/resume` — re-activates [sessionId] without history replay. Same
  /// result contract as [loadSession].
  Future<AcpNewSessionResult> resumeSession({
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) => _activateSession(method: AcpMethods.sessionResume, sessionId: sessionId, cwd: cwd, timeout: timeout);

  /// One `session/list` page; [cwd] null means the unfiltered form.
  Future<AcpSessionListResult> listSessionsPage({
    required String? cwd,
    required String? cursor,
    required Duration timeout,
  }) async {
    final raw = await client.request(
      method: AcpMethods.sessionList,
      params: {"cwd": ?cwd, "cursor": ?cursor},
      timeout: timeout,
    );
    return AcpSessionListResult.fromJson(_asJson(raw));
  }

  /// `session/set_config_option`. Returns the agent's updated config state, or
  /// null when it answered without one.
  Future<AcpNewSessionResult?> setConfigOption({
    required String sessionId,
    required String configId,
    required String value,
    required Duration timeout,
  }) async {
    final raw = await client.request(
      method: AcpMethods.sessionSetConfigOption,
      params: {"sessionId": sessionId, "configId": configId, "value": value},
      timeout: timeout,
    );
    return raw is Map ? AcpNewSessionResult.fromJson(raw.cast<String, dynamic>()) : null;
  }

  Future<void> closeSession({
    required String sessionId,
    required Duration timeout,
  }) => client.request(
    method: AcpMethods.sessionClose,
    params: {"sessionId": sessionId},
    timeout: timeout,
  );

  Future<AcpNewSessionResult> _activateSession({
    required String method,
    required String sessionId,
    required String cwd,
    required Duration timeout,
  }) async {
    final raw = await client.request(
      method: method,
      params: {
        "sessionId": sessionId,
        ..._sessionActivationParams(cwd: cwd),
      },
      timeout: timeout,
    );
    if (raw is! Map) throw StateError("$method returned no session for $sessionId");
    return AcpNewSessionResult.fromJson(raw.cast<String, dynamic>());
  }

  /// The bridge never injects MCP servers, but the field is required by the
  /// spec for `session/new`, `session/load`, and `session/resume`.
  static Map<String, dynamic> _sessionActivationParams({required String cwd}) => {
    "cwd": cwd,
    "mcpServers": const <Object?>[],
  };

  static Map<String, dynamic> _asJson(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};

  static String? _firstNonTerminalAuthMethod({
    required AcpInitializeResult init,
    required Set<String>? allowlist,
  }) {
    for (final method in init.authMethods) {
      if (method.type != AcpAuthMethodType.terminal && (allowlist == null || allowlist.contains(method.id))) {
        return method.id;
      }
    }
    return null;
  }
}
