import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show sesoriAgentInstructions;

import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";
import "../models/claude_process_purpose.dart";
import "claude_process_launch.dart";
import "models/claude_sesori_mcp_config_file.dart";

/// Whether a launch starts a brand-new session or continues an existing one.
///
/// A launch is exactly one of these. Modelling them as separate variants keeps
/// "new and resumed at once" and "neither" unrepresentable, and each carries
/// only the session id it needs.
sealed class ClaudeSessionLaunch({
  /// The Claude session id. For a new session the bridge pre-generates it so
  /// the Sesori-to-backend binding is durable from the very first event.
  required final String sessionId,
}) {
  /// Rejects an id the CLI would refuse.
  ///
  /// `--session-id` requires a UUID, and every transcript filename observed was
  /// one, so a non-UUID id is always a defect — either a caller that minted the
  /// wrong thing or a corrupted persisted row. Failing here names the problem;
  /// failing at spawn surfaces it as an opaque CLI startup error attached to a
  /// session the user just tried to open.
  this {
    if (!_uuidPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, "sessionId", "must be a UUID");
    }
  }
}

/// Starts a new session under a bridge-generated id (`--session-id`).
final class ClaudeNewSession({required super.sessionId}) extends ClaudeSessionLaunch;

/// Continues an existing session from its transcript (`--resume`).
final class ClaudeResumedSession({required super.sessionId}) extends ClaudeSessionLaunch;

/// Continues an existing session cut back to one of its chain entries
/// (`--resume` with `--resume-session-at`).
///
/// The process keeps [entryUuid] and every record before it, drops the rest in
/// memory and parents the next prompt to [entryUuid]. The file is not
/// rewritten: it becomes a tree whose newest leaf a later plain `--resume`
/// follows. An unknown entry makes the CLI exit before the handshake with
/// `No message found with message.uuid of: …`. The flag is hidden from
/// `--help` but present from 1.0.125 through 2.1.322, and the Agent SDK
/// documents it as `resumeSessionAt` (verified live on 2.1.221 and 2.1.322).
final class ClaudeRewoundSession({required super.sessionId, required final String entryUuid})
    extends ClaudeSessionLaunch {
  this {
    if (!_uuidPattern.hasMatch(entryUuid)) {
      throw ArgumentError.value(entryUuid, "entryUuid", "must be a UUID");
    }
  }
}

final RegExp _uuidPattern = RegExp(
  r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
);

/// The verified command line for one long-lived Claude stream-json process.
///
/// One process serves exactly one session, with the session's directory as its
/// working directory. The process stays alive for as long as its stdin stays
/// open; closing stdin is what ends it.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 1.
class ClaudeLaunchSpec({
  /// The `claude` executable: a `--claude-bin` override or a PATH name.
  required final String binaryPath,

  /// The session's directory, which becomes the process's working directory and
  /// therefore the project the session belongs to.
  required final String workingDirectory,

  /// Whether this launch creates or resumes a session.
  required final ClaudeSessionLaunch launch,

  /// Whether the process serves a session or only a catalog probe.
  required final ClaudeProcessPurpose purpose,

  /// Model selection token from the catalog (`ClaudeModel.value`), or null to
  /// let the CLI pick the account default.
  required final String? model,

  /// Reasoning effort, or null when the selected model does not support it.
  required final ClaudeEffortLevel? effort,

  /// Starting permission mode, or null to accept the CLI's own default.
  required final ClaudePermissionMode? permissionMode,
  required List<String> allowedTools,

  /// Sesori's transcripts folder (`sesoriTranscriptsDirectory()`), which the
  /// agent may read without asking.
  required final String transcriptsDirectory,

  /// Sesori's prompt uploads folder (`sesoriUploadsDirectory()`), which the
  /// agent may read without asking.
  required final String uploadsDirectory,

  /// The config file that gives this launch Sesori's own MCP server, or null
  /// to inject none: agent tools are off, or the process is a catalog probe.
  required final ClaudeSesoriMcpConfigFile? sesoriMcp,
  Map<String, String> environment = const {},
}) {
  /// Extra environment entries merged over the bridge's own environment.
  /// [ClaudeProcessLaunch] rejects a `HOME` override.
  final Map<String, String> environment = Map.unmodifiable(environment);

  /// Session-scoped rules granted by the user and restored after idle respawn.
  final List<String> allowedTools = List.unmodifiable(allowedTools);

  /// Routes tool-permission asks to us over stdio as `can_use_tool` control
  /// requests.
  ///
  /// This flag is REQUIRED and is deliberately not optional. It does not appear
  /// in `claude --help`; it was found in the Agent SDK's argument builder and
  /// confirmed live. Without it the CLI silently auto-denies every
  /// permission-gated tool: no control request is sent, each refused tool only
  /// fails its own step, and the turn still reports `subtype: "success"`. A
  /// plugin missing this flag looks healthy while every write, edit, and
  /// command fails, so the launch-spec test guards it rather than a turn error.
  static const List<String> permissionPromptToolArguments = ["--permission-prompt-tool", "stdio"];

  /// Keeps a catalog probe's hooks and MCP servers off. A project's probe
  /// also runs in a mirror of only its command and skill folders, so it loads
  /// no project settings (see `ClaudeCommandFilesApi.createProbeMirror`).
  /// Verified live on
  /// 2026-11-13 with Claude Code 2.1.323: without these flags a probe ran the
  /// project's SessionStart hook and started its `.mcp.json` server; with them
  /// neither ran. MCP prompts are not in the handshake's command list, so the
  /// probe loses no command by skipping MCP servers. Managed-policy hooks can
  /// still run: an organisation sets those to run on every launch.
  static const List<String> catalogProbeIsolationArguments = [
    "--settings", '{"disableAllHooks":true}',
    // With no `--mcp-config`, this loads no MCP server at all.
    "--strict-mcp-config",
  ];

  /// A rule that lets the agent read everything under [directory] without a
  /// permission request, and grants nothing else: `Edit` and `Write` stay
  /// gated.
  ///
  /// Claude spells an absolute path as `//` followed by the path without its
  /// leading `/`, so a POSIX root gains one `/`. On Windows Claude matches paths
  /// in POSIX form (`C:\Users\a` as `/c/Users/a`, per Claude's permission
  /// docs), so a drive path is converted first. Verified live on macOS on 2026-11-15 with Claude Code 2.1.325: with the rule
  /// a `-p` turn read a file under the folder, including through a folder name
  /// with a space; without it the read was refused, and a Write there was still
  /// refused with it.
  static String _readOnlyDirectoryRule({required String directory}) => "Read(/${_posixPath(directory: directory)}/**)";

  static String _posixPath({required String directory}) {
    if (!_windowsDrivePathPattern.hasMatch(directory)) return directory;
    final drive = directory.substring(0, 1).toLowerCase();
    final rest = directory.substring(3).replaceAll(r"\", "/");
    return "/$drive/$rest";
  }

  static final RegExp _windowsDrivePathPattern = RegExp(r"^[A-Za-z]:[\\/]");

  /// Pre-allows every tool of Sesori's server. The bridge asks the user for
  /// each proposing tool itself, so a native prompt would ask twice.
  static String _sesoriMcpToolRule({required ClaudeSesoriMcpConfigFile server}) => "mcp__${server.serverName}";

  /// The child process this spec starts.
  ClaudeProcessLaunch get processLaunch => ClaudeProcessLaunch(
    binaryPath: binaryPath,
    arguments: arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );

  /// The full argument vector, excluding the executable itself.
  List<String> get arguments => [
    // `--print` is mandatory: the stream-json input/output formats and partial
    // message streaming are all documented as print-mode only.
    "-p",
    "--input-format", "stream-json",
    "--output-format", "stream-json",
    // Required for full stream-json output.
    "--verbose",
    // Enables the token-level `stream_event` deltas the client renders.
    "--include-partial-messages",
    // Re-emits every stdin user turn on stdout under its transcript uuid, so
    // the live user message and the transcript backfill row share one id and
    // can never duplicate. Verified live: the replay arrives before the turn's
    // assistant output on both --session-id and --resume launches.
    "--replay-user-messages",
    ...permissionPromptToolArguments,
    // Sent on every launch. The CLI records the system prompt on a
    // conversation's first request and replays that record on resume until the
    // conversation is compacted, which is when a resumed launch's text applies.
    "--append-system-prompt", sesoriAgentInstructions,
    // Pattern-bound rather than null-checked so a later edit cannot separate the
    // check from the dereference.
    if (permissionMode case final mode?) ...["--permission-mode", mode.cliValue],
    if (model case final model?) ...["--model", model],
    if (effort case final effort?) ...["--effort", effort.wireValue],
    // Sesori writes transcripts and prompt uploads outside the session's
    // directory and passes their absolute paths in prompts, so reading them
    // must not ask. The session's granted rules follow.
    "--allowedTools",
    _readOnlyDirectoryRule(directory: transcriptsDirectory),
    _readOnlyDirectoryRule(directory: uploadsDirectory),
    if (sesoriMcp case final server?) _sesoriMcpToolRule(server: server),
    ...allowedTools,
    // Without `--strict-mcp-config` Claude adds Sesori's server to the user's
    // own, and nothing reaches the user's configuration, so a later plain
    // `claude --resume` loads no Sesori server.
    if (sesoriMcp case final server?) ...["--mcp-config", server.path],
    if (purpose == ClaudeProcessPurpose.catalogProbe) ...catalogProbeIsolationArguments,
    // Single-token `--flag=value`, matching the Agent SDK's own argument builder
    // (`sdk.mjs` emits `--session-id=${id}` and `--resume=${id}`). The CLI
    // accepts both spellings, so this is parity rather than correctness — but
    // parity is the contract this package holds itself to, and it removes a
    // place for future drift.
    ...switch (launch) {
      ClaudeNewSession() => ["--session-id=${launch.sessionId}"],
      ClaudeResumedSession() => ["--resume=${launch.sessionId}"],
      ClaudeRewoundSession(:final entryUuid) => ["--resume=${launch.sessionId}", "--resume-session-at=$entryUuid"],
    },
  ];
}
