import "package:acp_plugin/acp_plugin.dart";

/// Builds the launch spec for `omp acp` and declares the handshake policy every
/// Sesori ACP connection to it (live plugin, catalog and cleanup leases) uses.
abstract final class OmpBinary() {
  static const String defaultBinary = "omp";

  /// The ACP auth method OMP advertises for its locally configured agent.
  static const String acpAuthMethodId = "agent";

  /// Arguments of OMP's shared helper processes: the per-user daemon from
  /// 19.0.0 and, before it, the per-project broker and the machine-wide tiny
  /// title (ONNX) and mnemopi embedding workers. An `omp` process spawns a
  /// helper detached when none runs yet and every other `omp` process then
  /// uses it too, so stopping Sesori's `omp` leaves it running. Each exits on
  /// its own once idle. 18.x's MLX tiny worker runs a staged Python script with
  /// no stable argument, so it is not covered.
  static const Set<String> sharedHelperArguments = {
    "__omp_worker_daemon",
    "__omp_worker_daemon_broker",
    "__omp_worker_tiny_inference",
    "__omp_worker_mnemopi_embed_server",
  };

  /// From 19.0.0 OMP asks for a tool call's intent only in its own TUI unless
  /// this is set. ACP tool titles show that intent and fall back to
  /// `<tool>: <subject>` without it. Older releases already default to on.
  static const Map<String, String> _environment = {"PI_INTENT_TRACING": "1"};

  static AcpLaunchSpec launchSpec({
    required String binary,
    required String cwd,
    required String? sessionDirectory,
  }) => AcpLaunchSpec(
    includeParentEnvironment: true,
    command: binary,
    args: [
      "acp",
      if (sessionDirectory != null) ...["--session-dir", sessionDirectory],
    ],
    cwd: cwd,
    environment: _environment,
  );
}
