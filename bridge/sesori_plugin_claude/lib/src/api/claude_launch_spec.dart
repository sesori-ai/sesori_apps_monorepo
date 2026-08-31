import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";

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

final RegExp _uuidPattern = RegExp(
  r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
);

/// The verified command line for one long-lived Claude stream-json process.
///
/// One process serves exactly one session, with the session's directory as its
/// working directory. The process stays alive for as long as its stdin stays
/// open; closing stdin is what ends it.
///
/// Verified against Claude CLI 2.1.251 — see
/// `.plan/completed/claude-code-plugin/PROTOCOL.md` section 1.
class ClaudeLaunchSpec({
  /// The `claude` executable: a `--claude-bin` override or a PATH name.
  required final String binaryPath,

  /// The session's directory, which becomes the process's working directory and
  /// therefore the project the session belongs to.
  required final String workingDirectory,

  /// Whether this launch creates or resumes a session.
  required final ClaudeSessionLaunch launch,

  /// Model selection token from the catalog (`ClaudeModel.value`), or null to
  /// let the CLI pick the account default.
  required final String? model,

  /// Reasoning effort, or null when the selected model does not support it.
  required final ClaudeEffortLevel? effort,

  /// Starting permission mode, or null to accept the CLI's own default.
  required final ClaudePermissionMode? permissionMode,
  required List<String> allowedTools,

  /// Owner-only MCP configuration generated for this child, when available.
  final String? mcpConfigPath,
  Map<String, String> environment = const {},
}) {
  this {
    if (this.environment.containsKey("HOME")) {
      throw ArgumentError.value(
        this.environment,
        "environment",
        "must not override HOME; use CLAUDE_CONFIG_DIR for isolation",
      );
    }
  }

  /// Extra environment entries merged over the bridge's own environment.
  ///
  /// `HOME` must never appear here. Overriding it breaks macOS keychain lookup
  /// and makes a logged-in user look logged out. Test isolation uses
  /// `CLAUDE_CONFIG_DIR` instead.
  final Map<String, String> environment = Map.unmodifiable(environment);

  /// Session-scoped rules granted by the user and restored after idle respawn.
  final List<String> allowedTools = List.unmodifiable(allowedTools);

  /// Routes tool-permission asks to us over stdio as `can_use_tool` control
  /// requests.
  ///
  /// This flag is REQUIRED and is deliberately not optional. It does not appear
  /// in `claude --help`; it was found in the Agent SDK's argument builder and
  /// confirmed live. Without it the CLI silently auto-denies every
  /// permission-gated tool: no control request is sent, the turn still reports
  /// `subtype: "success"`, and the refusal is visible only in the result's
  /// `permission_denials` array. A plugin missing this flag looks healthy while
  /// every write, edit, and command fails.
  static const List<String> permissionPromptToolArguments = ["--permission-prompt-tool", "stdio"];

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
    // Pattern-bound rather than null-checked so a later edit cannot separate the
    // check from the dereference.
    if (permissionMode case final mode?) ...["--permission-mode", mode.cliValue],
    if (model case final model?) ...["--model", model],
    if (effort case final effort?) ...["--effort", effort.wireValue],
    if (allowedTools.isNotEmpty) ...["--allowedTools", ...allowedTools],
    if (mcpConfigPath case final path?) ...["--mcp-config", path],
    // Single-token `--flag=value`, matching the Agent SDK's own argument builder
    // (`sdk.mjs` emits `--session-id=${id}` and `--resume=${id}`). The CLI
    // accepts both spellings, so this is parity rather than correctness — but
    // parity is the contract this package holds itself to, and it removes a
    // place for future drift.
    switch (launch) {
      ClaudeNewSession() => "--session-id=${launch.sessionId}",
      ClaudeResumedSession() => "--resume=${launch.sessionId}",
    },
  ];
}
