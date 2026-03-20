import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Convenience factory for [RelayRequest] instances in tests.
RelayRequest makeRequest(
  String method,
  String path, {
  Map<String, String> headers = const {},
  String? body,
}) =>
    RelayMessage.request(
          id: "test-id",
          method: method,
          path: path,
          headers: headers,
          body: body,
        )
        as RelayRequest;

/// Hand-written fake [BridgePlugin] used across routing handler tests.
class FakeBridgePlugin implements BridgePlugin {
  final _controller = StreamController<BridgeSseEvent>.broadcast();

  // ── Configurable return values ───────────────────────────────────────────

  List<PluginProject> projectsResult = [];
  List<PluginSession> sessionsResult = [];
  List<PluginMessageWithParts> messagesResult = [];
  PluginProvidersResult providersResult = const PluginProvidersResult(providers: []);

  int proxyStatus = 200;
  Map<String, String> proxyHeaders = {};
  String? proxyBody;

  // ── Recorded call arguments ──────────────────────────────────────────────

  String? lastGetSessionsWorktree;
  int? lastGetSessionsStart;
  int? lastGetSessionsLimit;

  String? lastGetMessagesSessionId;

  bool? lastGetProvidersConnectedOnly;

  String? lastProxyMethod;
  String? lastProxyPath;
  Map<String, String>? lastProxyHeaders;
  String? lastProxyBody;

  // ── Error injection ──────────────────────────────────────────────────────

  bool throwOnHealthCheck = false;
  bool throwOnGetProjects = false;
  bool throwOnGetSessions = false;

  // ── BridgePlugin implementation ──────────────────────────────────────────

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  @override
  Future<String> healthCheck() async {
    if (throwOnHealthCheck) throw Exception("healthCheck error");
    return '{"status":"ok"}';
  }

  @override
  Future<List<PluginProject>> getProjects() async {
    if (throwOnGetProjects) throw Exception("getProjects error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async {
    if (throwOnGetSessions) throw Exception("getSessions error");
    lastGetSessionsWorktree = worktree;
    lastGetSessionsStart = start;
    lastGetSessionsLimit = limit;
    return sessionsResult;
  }

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async {
    lastGetMessagesSessionId = sessionId;
    return messagesResult;
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @Deprecated("Temporary proxy")
  @override
  Future<({int status, Map<String, String> headers, String? body})> proxyRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
  }) async {
    lastProxyMethod = method;
    lastProxyPath = path;
    lastProxyHeaders = headers;
    lastProxyBody = body;
    return (status: proxyStatus, headers: proxyHeaders, body: proxyBody);
  }

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    lastGetProvidersConnectedOnly = connectedOnly;
    return providersResult;
  }

  @override
  Future<void> dispose() async {}

  Future<void> close() => _controller.close();
}
