import 'dart:io';

import 'package:args/args.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

import '../../server/acp_binary_resolver.dart';
import '../../server/codex_binary_resolver.dart';
import '../../server/foundation/process_identity.dart';
import '../../server/models/open_code_ownership_record.dart';
import '../../server/process.dart';
import '../../server/repositories/open_code_ownership_repository.dart';
import '../../server/repositories/startup_mutex_repository.dart';
import '../../server/services/bridge_instance_service.dart';
import '../../server/services/open_code_server_service.dart';
import 'backend_registry.dart';
import 'bridge_cli_options.dart';

const String defaultTargetHost = 'http://127.0.0.1';

/// Resolves the backend server runtime according to [BridgeCliOptions.backend].
///
/// Both backends run inside the bridge startup mutex and single-live-bridge
/// enforcement — those guard the *bridge* process itself and are
/// backend-agnostic.
///
/// For `opencode`: starts (or validates) `opencode serve` and returns its
/// HTTP URL + Basic-auth password.
///
/// For `codex`: resolves the codex binary, spawns `codex app-server` on a
/// loopback WebSocket, and returns the discovered `ws://` URL. Loopback codex
/// needs no auth (`--ws-auth` is only required for non-loopback listeners).
Future<BridgeServerRuntime> resolveServer({
  required BridgeCliOptions options,
  // Null defaults to the opencode resolution path (the historical default).
  BackendDescriptor? descriptor,
  required ProcessIdentity currentBridgeIdentity,
  required String ownerSessionId,
  required StartupMutexRepository startupMutexRepository,
  required OpenCodeOwnershipRepository ownershipRepository,
  required BridgeInstanceService bridgeInstanceService,
  required OpenCodeServerService openCodeServerService,
}) async {
  final requestedPort = options.port;
  if (options.noAutoStart && requestedPort == null) {
    throw ArgParserException('The --no-auto-start flag requires --port to be set.');
  }

  return startupMutexRepository.withLock<BridgeServerRuntime>(
    bridgePid: currentBridgeIdentity.pid,
    bridgeStartMarker: currentBridgeIdentity.startMarker,
    onLockAcquired: () async {
      Log.d("acquired startup lock");
      final resolution = await bridgeInstanceService.enforceSingleLiveBridge(
        currentPid: currentBridgeIdentity.pid,
      );
      switch (resolution.status) {
        case BridgeInstanceResolutionStatus.allowed:
          if (descriptor != null && descriptor.isAcp) {
            return _resolveAcpServer(options, descriptor);
          }
          if (descriptor?.id == "codex") {
            return _resolveCodexServer(options);
          }
          if (options.noAutoStart) {
            try {
              final runtime = await openCodeServerService.validateExistingServer(
                port: requestedPort!,
                password: options.password.normalize(),
              );
              Log.i('Using existing server at ${runtime.serverUri} (auto-start disabled)');
              return BridgeServerRuntime.fromOpenCodeRuntime(
                runtime: runtime,
                ownedOpenCodeRecord: null,
              );
            } on OpenCodeServerStartException catch (error) {
              Log.w(
                'Cannot reach OpenCode at port $requestedPort (auto-start disabled): $error. Bridge will start anyway; start OpenCode manually to enable proxying.',
              );
              return BridgeServerRuntime(
                serverUrl: '$defaultTargetHost:$requestedPort',
                serverPassword: options.password.normalize(),
                process: null,
                ownedOpenCodeRecord: null,
                port: requestedPort!,
              );
            }
          }

          Log.d("[OPENCODE] Starting new instance");
          final runtime = await openCodeServerService.start(
            executablePath: options.opencodeBin,
            requestedPort: requestedPort,
            password: options.password.normalize(),
            terminatedBridgeIdentities: resolution.terminatedBridges,
          );

          Log.d("[OPENCODE] Started on port ${runtime.port}");
          final ownedOpenCodeRecord = await ownershipRepository.readByOwnerSessionId(
            ownerSessionId: ownerSessionId,
          );

          return BridgeServerRuntime.fromOpenCodeRuntime(
            runtime: runtime,
            ownedOpenCodeRecord: ownedOpenCodeRecord?.status == OpenCodeOwnershipStatus.ready
                ? ownedOpenCodeRecord
                : null,
          );
        case BridgeInstanceResolutionStatus.declined:
          throw const BridgeRuntimeServerException(
            'Startup aborted because another Sesori bridge is already running and replacement was declined.',
          );
        case BridgeInstanceResolutionStatus.nonInteractive:
          throw const BridgeRuntimeServerException(
            'Startup aborted because another Sesori bridge is already running and this session is non-interactive.',
          );
      }
    },
    onLockRejected: (result) async {
      switch (result) {
        case StartupMutexAcquireResult.alreadyLocked:
          throw const BridgeRuntimeServerException(
            'Startup aborted because another Sesori bridge startup is already in progress.',
          );
      }
    },
  );
}

/// Resolves the codex binary, spawns `codex app-server` on a loopback
/// WebSocket and returns the discovered `ws://` URL.
Future<BridgeServerRuntime> _resolveCodexServer(BridgeCliOptions options) async {
  if (options.noAutoStart) {
    throw const BridgeRuntimeServerException(
      'codex backend does not support --no-auto-start; '
      'remove the flag or use --backend opencode.',
    );
  }

  final resolver = CodexBinaryResolver(codexBinFlag: options.codexBin);
  final binaryPath = await resolver.resolve();

  final startup = await startCodexAppServer(
    binaryPath: binaryPath,
    requestedPort: options.codexPort,
  );

  Log.i('codex app-server started at ${startup.serverUrl}');
  return BridgeServerRuntime(
    serverUrl: startup.serverUrl,
    // Loopback codex requires no auth; non-loopback would be future scope.
    serverPassword: null,
    process: startup.process,
    ownedOpenCodeRecord: null,
    port: Uri.parse(startup.serverUrl).port,
  );
}

/// Resolves the binary for an ACP (stdio) harness. The plugin spawns and owns
/// the agent subprocess itself, so this only resolves the binary path and
/// carries it on the runtime — it does not start a server.
Future<BridgeServerRuntime> _resolveAcpServer(
  BridgeCliOptions options,
  BackendDescriptor descriptor,
) async {
  final config = descriptor.acp!;
  final flag = config.binaryFlag(options);
  final binary =
      AcpBinaryResolver(binaryFlag: flag.isEmpty ? config.defaultBinary : flag)
          .resolve();
  Log.i('${config.displayName} ACP backend using binary: $binary');
  return BridgeServerRuntime(
    // serverUrl is only used for a diagnostic log line for stdio backends.
    serverUrl: binary,
    serverPassword: null,
    process: null,
    ownedOpenCodeRecord: null,
    port: 0,
    acpBinaryPath: binary,
  );
}

class BridgeServerRuntime {
  const BridgeServerRuntime({
    required this.serverUrl,
    required this.serverPassword,
    required this.process,
    required this.ownedOpenCodeRecord,
    required this.port,
    this.acpBinaryPath,
  });

  factory BridgeServerRuntime.fromOpenCodeRuntime({
    required OpenCodeServerRuntime runtime,
    required OpenCodeOwnershipRecord? ownedOpenCodeRecord,
  }) {
    return BridgeServerRuntime(
      serverUrl: runtime.serverUri.toString(),
      serverPassword: runtime.serverPassword,
      process: runtime.process,
      ownedOpenCodeRecord: ownedOpenCodeRecord,
      port: runtime.port,
    );
  }

  final String serverUrl;
  final String? serverPassword;
  final Process? process;
  final OpenCodeOwnershipRecord? ownedOpenCodeRecord;
  final int port;

  /// Resolved agent binary for ACP (stdio) backends — passed to the plugin,
  /// which spawns and owns the subprocess. Null for socket/HTTP backends.
  final String? acpBinaryPath;
}

class BridgeRuntimeServerException implements Exception {
  const BridgeRuntimeServerException(this.message);

  final String message;

  @override
  String toString() => message;
}
