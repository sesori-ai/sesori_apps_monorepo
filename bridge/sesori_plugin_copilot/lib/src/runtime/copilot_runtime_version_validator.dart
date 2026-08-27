import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "copilot_runtime_manifest.dart";

/// Requires Copilot's branded `--version` line before accepting a candidate.
class CopilotRuntimeVersionValidator({
  required super.commandExecutor,
  required super.probeTimeout,
}) extends RuntimeVersionValidator {
  this : super(manifest: const CopilotRuntimeManifest());
  static final RegExp _versionLine = RegExp(
    r"^GitHub Copilot CLI\s+(\d+\.\d+\.\d+)\.?\s*$",
    multiLine: true,
  );

  @override
  RuntimeVersion? parseVersionOutput({required String output}) {
    final value = _versionLine.firstMatch(output)?.group(1);
    return value == null ? null : const CopilotRuntimeManifest().parseVersion(value: value);
  }
}
