import "bridge_sse_event.dart";
import "models/plugin_agent.dart";
import "models/plugin_command.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_permission.dart";
import "models/plugin_pending_question.dart";
import "models/plugin_project.dart";
import "models/plugin_project_activity_summary.dart";
import "models/plugin_prompt_part.dart";
import "models/plugin_provider.dart";
import "models/plugin_session.dart";
import "models/plugin_session_status.dart";
import "models/plugin_session_variant.dart";
import "plugin_permission_reply.dart";

// Note: as far as architecture goes, this MUST be treated as part of API layer
/// The backend contract every bridge plugin fulfils.
///
/// Sealed so that project ownership is expressed in the type system: a plugin
/// is either a [NativeProjectsPluginApi] (its backend owns the project list)
/// or a [BridgeDerivedProjectsPluginApi] (the bridge derives projects from the
/// plugin's sessions). Bridge code switches over the two subtypes — there is
/// no capability enum to keep in sync and no `UnsupportedError` stubs for
/// members a plugin cannot honour.
sealed class BridgePluginApi {
  /// Unique plugin identifier (e.g., "opencode", "codex")
  String get id;

  /// Stream of bridge SSE events. Buffered until the first listener subscribes,
  /// then broadcast to every attached listener.
  Stream<BridgeSseEvent> get events;

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
  ///
  /// [parts] is the exact backend execution payload and may include
  /// bridge-owned context. [userVisibleText] is only the user-authored text,
  /// or `null` when no user text should be rendered. Implementations that
  /// synthesize a client-facing user message MUST use [userVisibleText], never
  /// infer it from [parts].
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  /// Rename a session's title.
  Future<PluginSession> renameSession({required String sessionId, required String title});

  Future<void> deleteSession(String sessionId);

  /// Notify the backend that a session has been archived.
  ///
  /// This is best-effort — the local database archive state is authoritative.
  /// Unarchive is not propagated to the backend; it only clears the local DB.
  Future<void> archiveSession({required String sessionId});

  /// Delete a workspace (git worktree / sandbox) from the backend.
  ///
  /// This is best-effort — the caller should have already removed the worktree
  /// from disk. If the workspace is already gone or the backend does not
  /// recognize it, the call should succeed silently.
  ///
  /// [worktreePath] is the specific worktree directory to remove.
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  });

  Future<List<PluginSession>> getChildSessions(String sessionId);

  Future<Map<String, PluginSessionStatus>> getSessionStatuses();

  /// Get all messages for a session.
  ///
  /// An empty list means a **genuinely empty thread** (including a backend
  /// that cannot serve history at all). Implementations MUST throw — e.g. a
  /// [PluginOperationException] — when history retrieval *fails* (transport,
  /// auth, replay errors), never swallow the failure into an empty list: the
  /// phone renders an error-with-retry state for a failed load, which must
  /// stay distinguishable from "no messages yet".
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  /// Sends a slash command to a session.
  ///
  /// The returned future MUST complete once the backend has **accepted** the
  /// command for execution — not when the command's run finishes. Callers
  /// (bridge request handlers serving phones) await this future while holding
  /// a client request open, so an implementation must never block for the
  /// duration of the command's agent run. If the backend only exposes a
  /// synchronous endpoint, the implementation is responsible for detaching
  /// (and surfacing later failures through its [events] stream / logs).
  ///
  /// Dispatch failures (unknown command, missing session, backend down) MUST
  /// be thrown so callers can report the send as failed.
  ///
  /// [arguments] is the exact backend execution payload and may include
  /// bridge-owned context. [userVisibleArguments] is only the user-authored
  /// portion, or `null` when none was supplied. Implementations that synthesize
  /// a client-facing command message MUST use that value, never [arguments].
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  });

  Future<void> abortSession({required String sessionId});

  /// Returns the agents available for the given project.
  ///
  /// [projectId] identifies the project; its format is plugin-defined.
  Future<List<PluginAgent>> getAgents({required String projectId});

  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId});

  /// Returns the pending permission requests to surface on [sessionId]'s
  /// screen: the session's own requests plus those of its descendant
  /// (sub-agent) sessions, whose top-most root resolves to [sessionId].
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId});

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

  Future<void> rejectQuestion({required String questionId, required String? sessionId});

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

  /// Health check — returns `true` when the backend is healthy, `false`
  /// otherwise.
  ///
  /// This is an *instantaneous*, plugin-scoped probe: it reflects backend
  /// reachability right now and is not debounced. It is not part of the
  /// bridge-level `/global/health` response. The debounced lifecycle signal
  /// used for orchestration decisions is `BridgePlugin.status`.
  Future<bool> healthCheck();

  /// Get connected providers and their models from the backend.
  Future<PluginProvidersResult> getProviders({
    required String projectId,
  });

  /// Build a summary of the active sessions for each project.
  List<PluginProjectActivitySummary> getActiveSessionsSummary();

  /// Stop the plugin and release resources (SSE connections, HTTP clients, etc.).
  ///
  /// Prefer `BridgePlugin.shutdown()`, which owns the plugin's ordered
  /// teardown; this method will be removed once the bridge core stops
  /// calling it directly. Until then the core may call `dispose()` before or
  /// after `shutdown()`, so implementations MUST be idempotent and safe in
  /// either order.
  Future<void> dispose();
}

/// A plugin whose backend owns the project list natively (e.g. OpenCode's
/// `/project` API). The bridge calls [getProjects] and treats the result as
/// authoritative.
abstract class NativeProjectsPluginApi extends BridgePluginApi {
  /// Get the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Get a project by its ID.
  Future<PluginProject> getProject(String projectId);

  /// Rename a project.
  Future<PluginProject> renameProject({required String projectId, required String name});
}

/// A plugin whose backend has no project concept (Codex and every ACP
/// backend): the bridge derives the project list by grouping the plugin's
/// sessions by directory, and owns opened-folder and rename-override
/// persistence itself — so this subtype carries no project members at all.
abstract class BridgeDerivedProjectsPluginApi extends BridgePluginApi {
  /// Every session this plugin knows about, across all projects. The bridge
  /// groups the result by [PluginSession.directory] to build the project list,
  /// so each returned session must carry its real working directory.
  ///
  /// [knownDirectories] is every directory the bridge itself attributes to
  /// this plugin — its stored project paths (opened folders and the owning
  /// projects of bridge-created sessions) plus the dedicated-worktree paths of
  /// its stored sessions. A backend whose enumeration is directory-scoped
  /// (ACP's `session/list` filters by cwd) must include these directories in
  /// its scan, or sessions from prior runs would vanish after a restart; a
  /// backend with a global index (codex's rollout files) may ignore them.
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories});

  /// The plugin's launch directory. The bridge seeds this as an opened folder so
  /// it always surfaces as a project — even with no sessions yet — matching the
  /// "there is always somewhere to start a session" behaviour derive-style
  /// backends had before the bridge owned their project list.
  String get launchDirectory;

  /// Hints the bridge's stored directory attribution for [sessionId] before an
  /// operation that carries only the session id (prompt dispatch, history
  /// replay). After a bridge restart a directory-scoped backend (ACP) may not
  /// have enumerated the session yet, so without this hint it would operate in
  /// its launch directory instead of the session's own cwd — the bridge's
  /// stored row (worktree path or owning project directory) is the durable
  /// attribution it cannot self-resolve. A hint, not an override: a backend
  /// keeps its own fresher attribution when it has one. The default is a
  /// no-op for backends with a global session index.
  void primeSessionDirectory({required String sessionId, required String directory}) {}
}
