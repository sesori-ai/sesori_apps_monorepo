import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";

/// Whether a launch starts a brand-new session or continues an existing one.
///
/// A launch is exactly one of these. Modelling them as separate variants keeps
/// "new and resumed at once" and "neither" unrepresentable, and each carries
/// only the session id it needs.
sealed class ClaudeSessionLaunch {
  /// Rejects an id the CLI would refuse.
  ///
  /// `--session-id` requires a UUID, and every transcript filename observed was
  /// one, so a non-UUID id is always a defect — either a caller that minted the
  /// wrong thing or a corrupted persisted row. Failing here names the problem;
  /// failing at spawn surfaces it as an opaque CLI startup error attached to a
  /// session the user just tried to open.
  ClaudeSessionLaunch({required this.sessionId}) {
    if (!_uuidPattern.hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, "sessionId", "must be a UUID");
    }
  }

  /// The Claude session id. For a new session the bridge pre-generates it so
  /// the Sesori-to-backend binding is durable from the very first event.
  final String sessionId;
}

/// Starts a new session under a bridge-generated id (`--session-id`).
final class ClaudeNewSession extends ClaudeSessionLaunch {
  ClaudeNewSession({required super.sessionId});
}

/// Continues an existing session from its transcript (`--resume`).
final class ClaudeResumedSession extends ClaudeSessionLaunch {
  ClaudeResumedSession({required super.sessionId});
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
/// `.plan/active/claude-code-plugin/PROTOCOL.md` section 1.
class ClaudeLaunchSpec {
  ClaudeLaunchSpec({
    required this.binaryPath,
    required this.launch,
    required this.model,
    required this.effort,
    required this.permissionMode,
  });

  /// The `claude` executable: a `--claude-bin` override or a PATH name.
  final String binaryPath;

  /// Whether this launch creates or resumes a session.
  final ClaudeSessionLaunch launch;

  /// Model selection token from the catalog (`ClaudeModel.value`), or null to
  /// let the CLI pick the account default.
  final String? model;

  /// Reasoning effort, or null when the selected model does not support it.
  final ClaudeEffortLevel? effort;

  /// Starting permission mode, or null to accept the CLI's own default.
  final ClaudePermissionMode? permissionMode;

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
    ...permissionPromptToolArguments,
    // Pattern-bound rather than null-checked so a later edit cannot separate the
    // check from the dereference.
    if (permissionMode case final mode?) ...["--permission-mode", mode.cliValue],
    if (model case final model?) ...["--model", model],
    if (effort case final effort?) ...["--effort", effort.wireValue],
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
