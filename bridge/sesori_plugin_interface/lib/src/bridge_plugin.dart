import "bridge_sse_event.dart";
import "models/plugin_agent.dart";
import "models/plugin_command.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_question.dart";
import "models/plugin_project.dart";
import "models/plugin_project_activity_summary.dart";
import "models/plugin_prompt_part.dart";
import "models/plugin_provider.dart";
import "models/plugin_session.dart";
import "models/plugin_session_status.dart";
import "models/plugin_session_variant.dart";
import "plugin_permission_reply.dart";

abstract class BridgePlugin {
  /// Unique plugin identifier (e.g., "opencode", "codex")
  String get id;

  /// Stream of bridge SSE events. Buffered until first listener subscribes.
  Stream<BridgeSseEvent> get events;

  /// Get the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Get sessions for a project directory.
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit});

  /// Get the slash commands available to the current project.
  Future<List<PluginCommand>> getCommands({required String? projectId});

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
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  /// Rename a session's title.
  Future<PluginSession> renameSession({required String sessionId, required String title});

  /// Rename a project.
  Future<PluginProject> renameProject({required String projectId, required String name});

  Future<void> deleteSession(String sessionId);

  /// Notify the backend that a session has been archived.
  ///
  /// This is best-effort — the local database archive state is authoritative.
  /// Unarchive is not propagated to the backend; it only clears the local DB.
  Future<void> archiveSession({required String sessionId});

  Future<List<PluginSession>> getChildSessions(String sessionId);

  Future<Map<String, PluginSessionStatus>> getSessionStatuses();

  /// Get all messages for a session.
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
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

  /// Responds to a pending permission request.
  ///
  /// [requestId] — the unique ID of the permission request
  /// [sessionId] — the session that owns this permission
  /// [reply] — once/always/reject
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  });

  /// Get a project by its ID.
  Future<PluginProject> getProject(String projectId);

  /// Health check — returns `true` when the backend is healthy, `false`
  /// otherwise.
  Future<bool> healthCheck();

  /// Get connected providers and their models from the backend.
  Future<PluginProvidersResult> getProviders({
    required String projectId,
  });

  /// Build a summary of the active sessions for each project.
  List<PluginProjectActivitySummary> getActiveSessionsSummary();

  /// Stop the plugin and release resources (SSE connections, HTTP clients, etc.).
  Future<void> dispose();
}
