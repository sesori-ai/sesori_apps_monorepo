import "bridge_sse_event.dart";
import "models/plugin_agent.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_question.dart";
import "models/plugin_project.dart";
import "models/plugin_project_activity_summary.dart";
import "models/plugin_prompt_part.dart";
import "models/plugin_provider.dart";
import "models/plugin_session.dart";
import "models/plugin_session_status.dart";

abstract class BridgePlugin {
  /// Unique plugin identifier (e.g., "opencode", "codex")
  String get id;

  /// Stream of bridge SSE events. Buffered until first listener subscribes.
  Stream<BridgeSseEvent> get events;

  /// Get the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Get sessions for a worktree directory.
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit});

  Future<PluginSession> createSession(String worktree);

  Future<PluginSession> updateSessionArchiveStatus(String sessionId, {required int? archivedAt});

  Future<void> deleteSession(String sessionId);

  Future<List<PluginSession>> getChildSessions(String sessionId);

  Future<Map<String, PluginSessionStatus>> getSessionStatuses();

  /// Get messages for a session (last exchange).
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    String? agent,
    String? providerID,
    String? modelID,
  });

  Future<void> abortSession(String sessionId);

  Future<List<PluginAgent>> getAgents();

  Future<List<PluginPendingQuestion>> getPendingQuestions();

  Future<void> replyToQuestion(String questionId, {required List<List<String>> answers});

  Future<void> rejectQuestion(String questionId);

  Future<PluginProject> getCurrentProject(String worktree);

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

  /// Stop the plugin and release resources (SSE connections, HTTP clients, etc.).
  Future<void> dispose();
}
