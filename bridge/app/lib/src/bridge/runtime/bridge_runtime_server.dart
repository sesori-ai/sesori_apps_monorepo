import 'dart:io';

import 'package:args/args.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../server/foundation/process_identity.dart';
import '../../server/repositories/open_code_ownership_record.dart';
import '../../server/repositories/open_code_ownership_repository.dart';
import '../../server/repositories/startup_mutex_repository.dart';
import '../../server/services/bridge_instance_service.dart';
import '../../server/services/open_code_server_service.dart';
import 'bridge_cli_options.dart';

const String defaultTargetHost = 'http://127.0.0.1';

Future<BridgeServerRuntime> resolveServer({
  required BridgeCliOptions options,
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
          if (options.noAutoStart) {
            final runtime = await openCodeServerService.validateExistingServer(
              port: requestedPort!,
              password: _normalizePassword(password: options.password),
            );
            Log.i('Using existing server at ${runtime.serverUri} (auto-start disabled)');
            return BridgeServerRuntime.fromOpenCodeRuntime(
              runtime: runtime,
              ownedOpenCodeRecord: null,
            );
          }

          Log.d("Starting new opencode instance");

          final runtime = await openCodeServerService.start(
            executablePath: options.opencodeBin,
            requestedPort: requestedPort,
            password: _normalizePassword(password: options.password),
            terminatedBridgeIdentities: resolution.terminatedBridges,
          );
          final ownedOpenCodeRecord = await ownershipRepository.readByOwnerSessionId(
            ownerSessionId: ownerSessionId,
          );
          Log.i('opencode server started on port ${runtime.port}');
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

String? _normalizePassword({required String password}) {
  return password.isEmpty ? null : password;
}

class BridgeServerRuntime {
  const BridgeServerRuntime({
    required this.serverUrl,
    required this.serverPassword,
    required this.process,
    required this.ownedOpenCodeRecord,
    required this.port,
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
}

class BridgeRuntimeServerException implements Exception {
  const BridgeRuntimeServerException(this.message);

  final String message;

  @override
  String toString() => message;
}
