import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginStartAbortedException, StartAbortSignal;

import "../models/open_code_service_command_exception.dart";
import "../repositories/open_code_shared_server_repository.dart";
import "../runtime/open_code_runtime_policy.dart";
import "../runtime/open_code_shared_server_endpoint.dart";

/// Layer-3 policy for OpenCode 2's shared background server: use the running
/// service, or ask OpenCode to start it and use that. `null` means the caller
/// spawns its own private server as before.
///
/// The service is OpenCode's own detached process. Like one started by the
/// TUI, it outlives the bridge (user decision P1, 2026-10-08).
class const OpenCodeSharedServerService({required final OpenCodeSharedServerRepository repository}) {
  Future<OpenCodeSharedServerEndpoint?> acquire({
    required String? binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    final running = await repository.discover(environment: environment);
    if (running != null) return running;
    if (binary == null) return null;

    try {
      final version = await repository.readBinaryVersion(
        binary: binary,
        environment: environment,
        startAborted: startAborted,
      );
      if (version.version.compareTo(openCodeMinimumV2Version) < 0) {
        // OpenCode 1 has no shared service, and starting a v2 one instead
        // would migrate the user's database one way.
        Log.i("[opencode] OpenCode $version has no shared service; using a private server");
        return null;
      }
      if (await repository.isServiceDisabled(binary: binary, environment: environment, startAborted: startAborted)) {
        Log.i("[opencode] the shared OpenCode service is disabled in OpenCode; using a private server");
        return null;
      }
      Log.i("[opencode] starting the shared OpenCode $version service");
      await repository.startService(binary: binary, environment: environment, startAborted: startAborted);
    } on OpenCodeServiceCommandException catch (error) {
      Log.w(
        "[opencode] could not start the shared OpenCode service; using a private server: ${error.message}",
        error.cause,
      );
      return null;
    }
    if (startAborted.isAborted) throw const PluginStartAbortedException();

    final started = await repository.discover(environment: environment);
    if (started == null) {
      Log.w("[opencode] the shared OpenCode service started but is not usable; using a private server");
    }
    return started;
  }
}
