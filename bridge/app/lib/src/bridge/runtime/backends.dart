import "dart:io" show Directory;

import "package:codex_plugin/codex_plugin.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:opencode_plugin/opencode_plugin.dart";

import "acp_harness_config.dart";
import "backend_registry.dart";

/// The Cursor ACP harness — the first ACP backend. To add another ACP harness
/// (e.g. Gemini), add a sibling [AcpHarnessConfig] and a descriptor below; a
/// vanilla harness can use `AcpPlugin(...)` directly as its `pluginBuilder`.
final AcpHarnessConfig cursorHarness = AcpHarnessConfig(
  id: "cursor",
  displayName: "Cursor",
  defaultBinary: "cursor-agent",
  binaryFlag: (options) => options.cursorBin,
  pluginBuilder: ({required binaryPath, required projectCwd}) =>
      CursorPlugin(binaryPath: binaryPath, projectCwd: projectCwd),
);

/// Builds the backend registry. Each entry replaces an arm of the old
/// hardcoded `BridgeBackend` enum/switch.
BackendRegistry buildBackendRegistry() {
  return BackendRegistry([
    BackendDescriptor(
      id: "opencode",
      optimizesOpenCodeDb: true,
      createPlugin: (runtime) => OpenCodePlugin(
        serverUrl: runtime.serverUrl,
        password: runtime.serverPassword,
      ),
    ),
    BackendDescriptor(
      id: "codex",
      ownsProcessShutdown: true,
      createPlugin: (runtime) => CodexPlugin(
        serverUrl: runtime.serverUrl,
        capabilityToken: runtime.serverPassword,
      ),
    ),
    BackendDescriptor(
      id: cursorHarness.id,
      acp: cursorHarness,
      createPlugin: (runtime) => cursorHarness.pluginBuilder(
        binaryPath: runtime.acpBinaryPath ?? cursorHarness.defaultBinary,
        projectCwd: Directory.current.path,
      ),
    ),
  ]);
}
