import "models/claude_effort_level.dart";
import "models/claude_permission_mode.dart";

/// Whether a launch starts a brand-new session or continues an existing one.
///
/// A launch is exactly one of these. Modelling them as separate variants keeps
/// "new and resumed at once" and "neither" unrepresentable, and each carries
/// only the session id it needs.
sealed class ClaudeSessionLaunch {
  const ClaudeSessionLaunch({required this.sessionId});

  /// The Claude session id. For a new session the bridge pre-generates it so
  /// the Sesori-to-backend binding is durable from the very first event.
  final String sessionId;
}

/// Starts a new session under a bridge-generated id (`--session-id`).
final class ClaudeNewSession extends ClaudeSessionLaunch {
  const ClaudeNewSession({required super.sessionId});
}

/// Continues an existing session from its transcript (`--resume`).
final class ClaudeResumedSession extends ClaudeSessionLaunch {
  const ClaudeResumedSession({required super.sessionId});
}

/// The verified command line for one long-lived Claude stream-json process.
///
/// One process serves exactly one session, with the session's directory as its
/// working directory. The process stays alive for as long as its stdin stays
/// open; closing stdin is what ends it.
///
/// Verified against Claude CLI 2.1.221 — see
/// `.plan/active/claude-code-plugin/PROTOCOL.md` section 1.
class ClaudeLaunchSpec {
  const ClaudeLaunchSpec({
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
    if (permissionMode != null) ...["--permission-mode", permissionMode!.cliValue],
    if (model != null) ...["--model", model!],
    if (effort != null) ...["--effort", effort!.wireValue],
    switch (launch) {
      ClaudeNewSession() => "--session-id",
      ClaudeResumedSession() => "--resume",
    },
    launch.sessionId,
  ];
}
