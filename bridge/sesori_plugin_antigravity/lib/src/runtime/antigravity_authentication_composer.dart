import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/antigravity_acp_api.dart";
import "../authentication/antigravity_authentication_operation.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../clients/antigravity_loopback_client.dart";
import "../repositories/antigravity_authentication_repository.dart";
import "../repositories/antigravity_profile_repository.dart";
import "../repositories/antigravity_runtime_repository.dart";
import "../repositories/mappers/antigravity_authorization_mapper.dart";
import "../repositories/mappers/antigravity_stderr_mapper.dart";
import "../services/antigravity_authentication_service.dart";
import "../services/antigravity_profile_service.dart";
import "../services/antigravity_runtime_service.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/antigravity_runtime_storage.dart";

/// Per-attempt composition seam for the descriptor. Each invocation receives a
/// dedicated HTTP client and the SAME plugin-root store as live use.
class const AntigravityAuthenticationComposer() {
  PluginAuthenticationBrowserOperation compose({
    required HostProcessService processes,
    required HostJsonStore store,
    required HttpClient callbackHttpClient,
    required String stateDirectory,
    required Map<String, String> environment,
    required PlatformTarget target,
    required String browserExecutable,
    required List<String> browserPrefixArguments,
    required String? explicitServerPath,
    required String? managedServerPath,
    required StartAbortSignal aborted,
    required Duration timeout,
  }) {
    const launchSpecBuilder = AntigravityLaunchSpecBuilder();
    const stderrMapper = AntigravityStderrMapper();
    final acpApi = AntigravityAcpApi(
      processFactory: hostProcessAcpFactory(processes: processes, environment: environment),
      stderrInterceptor: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: stderrMapper.consumeLine),
    );
    final profile = AntigravityProfileService(
      repository: AntigravityProfileRepository(
        storage: AntigravityProfileStorage(
          geminiHome: p.join(stateDirectory, "profile"),
          settingsStore: store.scope(directoryName: "profile").scope(directoryName: "antigravity-acp"),
          commands: HostProcessCommandExecutor(
            processes: processes,
            runInShell: false,
            includeParentEnvironment: false,
            maxCapturedOutputCharactersPerStream: 4096,
          ),
          target: target,
        ),
      ),
      target: target,
      browserExecutable: browserExecutable,
      browserPrefixArguments: browserPrefixArguments,
    );
    final runtime = AntigravityRuntimeService(
      runtimeRepository: AntigravityRuntimeRepository(
        runtimeStorage: const AntigravityRuntimeStorage(),
        acpApi: acpApi,
        launchSpecBuilder: launchSpecBuilder,
      ),
    );
    final authentication = AntigravityAuthenticationService(
      repository: AntigravityAuthenticationRepository(
        acpApi: acpApi,
        loopbackClient: AntigravityLoopbackClient(client: callbackHttpClient),
        authorizationMapper: const AntigravityAuthorizationMapper(),
        launchSpecBuilder: launchSpecBuilder,
      ),
    );
    return AntigravityAuthenticationOperation(
      profile: profile,
      runtime: runtime,
      authentication: authentication,
      target: target,
      explicitServerPath: explicitServerPath,
      managedServerPath: managedServerPath,
      hostEnvironment: environment,
      aborted: aborted,
      timeout: timeout,
    ).operation;
  }
}
