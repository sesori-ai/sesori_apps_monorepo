import "bridge_sse_event.dart";
import "models/plugin_message.dart";
import "models/plugin_project.dart";
import "models/plugin_project_activity_summary.dart";
import "models/plugin_provider.dart";
import "models/plugin_session.dart";

abstract class BridgePlugin {
  /// Unique plugin identifier (e.g., "opencode", "codex")
  String get id;

  /// Stream of bridge SSE events. Buffered until first listener subscribes.
  Stream<BridgeSseEvent> get events;

  /// Get the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Get sessions for a worktree directory.
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit});

  /// Get messages for a session (last exchange).
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  /// Health check — returns the backend's health status as a JSON string.
  Future<String> healthCheck();

  /// Get providers and their models from the backend.
  ///
  /// When [connectedOnly] is `true`, only providers that have valid credentials
  /// configured are returned. When `false`, all known providers are returned
  /// regardless of whether they are connected.
  Future<PluginProvidersResult> getProviders({required bool connectedOnly});

  /// Build a summary of the active sessions for each project.
  List<PluginProjectActivitySummary> getActiveSessionsSummary();

  /// Proxy a raw HTTP request to the backend and return the response.
  ///
  /// This is a temporary escape hatch for routes not yet covered by typed
  /// plugin methods. Returns `(statusCode, headers, body)`.
  @Deprecated("Temporary proxy — replace with typed plugin methods")
  Future<({int status, Map<String, String> headers, String? body})> proxyRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
  });

  /// Stop the plugin and release resources (SSE connections, HTTP clients, etc.).
  Future<void> dispose();
}
