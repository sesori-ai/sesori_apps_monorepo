import "bridge_sse_event.dart";
import "models/plugin_agent.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_question.dart";
import "models/plugin_project.dart";
import "models/plugin_project_activity_summary.dart";
import "models/plugin_prompt_part.dart";
import "models/plugin_provider.dart";
import "models/plugin_session.dart";
import "models/plugin_session_metadata.dart";
import "models/plugin_session_status.dart";

abstract class BridgePlugin {
  /// Unique plugin identifier (e.g., "opencode", "codex")
  String get id;

  /// Stream of bridge SSE events. Buffered until first listener subscribes.
  Stream<BridgeSseEvent> get events;

  /// Get the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Get sessions for a project directory.
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit});

  /// Create a new session in the given directory and send the first prompt.
  ///
  /// [directory] is the working directory for the session (may be a worktree
  /// path or the main project path).
  ///
  /// If [parentSessionId] is provided, the new session is created as a
  /// child (sub-session) of the specified parent.
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  /// Rename a session's title.
  Future<PluginSession> renameSession({required String sessionId, required String title});

  /// Rename a project.
  Future<PluginProject> renameProject({required String projectId, required String name});

  Future<void> deleteSession(String sessionId);

  Future<List<PluginSession>> getChildSessions(String sessionId);

  Future<Map<String, PluginSessionStatus>> getSessionStatuses();

  /// Get all messages for a session.
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  Future<void> abortSession({required String sessionId});

  Future<List<PluginAgent>> getAgents();

  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId});

  /// Returns all pending questions for every session in the given project.
  ///
  /// [projectId] is the project worktree directory.
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId});

  /// Reply to a pending question prompt.
  ///
  /// [answers] is a `List<List<String>>` because:
  /// - The outer list contains one entry per question in the prompt
  ///   (a single prompt can ask multiple questions at once).
  /// - Each inner list contains the selected answers for that question
  ///   (supports multi-select — one or more values can be chosen).
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  });

  Future<void> rejectQuestion(String questionId);

  /// Get a project by its ID.
  Future<PluginProject> getProject(String projectId);

  /// Health check — returns `true` when the backend is healthy, `false`
  /// otherwise.
  Future<bool> healthCheck();

  /// Get providers and their models from the backend.
  ///
  /// When [connectedOnly] is `true`, only providers that have valid credentials
  /// configured are returned. When `false`, all known providers are returned
  /// regardless of whether they are connected.
  Future<PluginProvidersResult> getProviders({required bool connectedOnly});

  /// Build a summary of the active sessions for each project.
  List<PluginProjectActivitySummary> getActiveSessionsSummary();

  /// Generate session metadata (title and branch name) from the first message and directory.
  ///
  /// [firstMessage] is the initial user prompt text.
  /// [directory] is the working directory for the session.
  ///
  /// Returns [SessionMetadata] with suggested title and branch name, or null if generation fails.
  Future<SessionMetadata?> generateSessionMetadata({
    required String firstMessage,
    required String directory,
  });

  /// Stop the plugin and release resources (SSE connections, HTTP clients, etc.).
  Future<void> dispose();
}
