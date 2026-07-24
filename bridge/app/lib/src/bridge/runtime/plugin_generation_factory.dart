import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../server/api/loopback_port_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/host/bridge_host_info_impl.dart";
import "../../server/host/bridge_host_json_store.dart";
import "../../server/host/bridge_host_port_service.dart";
import "../../server/host/bridge_host_process_service.dart";
import "../../server/host/bridge_plugin_host_impl.dart";
import "../../server/host/plugin_state_directory.dart";
import "../../server/repositories/process_repository.dart";
import "../../server/repositories/startup_mutex_repository.dart";
import "../../server/services/bridge_instance_service.dart";
import "../../updater/models/managed_runtime_paths.dart";
import "bridge_runtime_server_exception.dart";

class PluginRuntimeRegistration {
  const PluginRuntimeRegistration({
    required this.descriptor,
    required this.config,
    required this.stateDirectory,
  });

  final BridgePluginDescriptor descriptor;
  final PluginConfig config;
  final String stateDirectory;
}

/// A failure isolated to one descriptor's runtime resolution or start attempt.
///
/// Shared startup infrastructure failures, such as bridge ownership or mutex
/// contention, are deliberately not wrapped so the composition root can abort
/// the whole bridge with their original typed exception.
class PluginGenerationStartFailedException implements Exception {
  const PluginGenerationStartFailedException({
    required this.pluginId,
    required this.cause,
  });

  final String pluginId;
  final Object cause;

  @override
  String toString() => 'PluginGenerationStartFailedException: Plugin "$pluginId" failed to start: $cause';
}

sealed class PluginGenerationStartEvent {
  const PluginGenerationStartEvent();
}

final class PluginGenerationProvisionProgress extends PluginGenerationStartEvent {
  const PluginGenerationProvisionProgress({required this.event});

  final RuntimeProvisionProgress event;
}

final class PluginGenerationStarted extends PluginGenerationStartEvent {
  const PluginGenerationStarted({required this.plugin});

  final BridgePlugin plugin;
}

class PluginGenerationFactory {
  PluginGenerationFactory({
    required ManagedRuntimePaths managedRuntimePaths,
    required ProcessIdentity currentBridgeIdentity,
    required String ownerSessionId,
    required StartupMutexRepository startupMutexRepository,
    required BridgeInstanceService bridgeInstanceService,
    required ProcessRepository processRepository,
    required RuntimeFileApi runtimeFileApi,
    required ServerClock clock,
    required Map<String, String> environment,
    required ProcessUser? currentUser,
  }) : _managedRuntimePaths = managedRuntimePaths,
       _currentBridgeIdentity = currentBridgeIdentity,
       _ownerSessionId = ownerSessionId,
       _startupMutexRepository = startupMutexRepository,
       _bridgeInstanceService = bridgeInstanceService,
       _processRepository = processRepository,
       _clock = clock,
       _environment = Map<String, String>.unmodifiable(environment),
       _currentUser = currentUser,
       _fileApisByStateDirectory = <String, RuntimeFileApi>{
         runtimeFileApi.runtimeDirectory: runtimeFileApi,
       };

  final ManagedRuntimePaths _managedRuntimePaths;
  final ProcessIdentity _currentBridgeIdentity;
  final String _ownerSessionId;
  final StartupMutexRepository _startupMutexRepository;
  final BridgeInstanceService _bridgeInstanceService;
  final ProcessRepository _processRepository;
  final ServerClock _clock;
  final Map<String, String> _environment;
  final ProcessUser? _currentUser;
  final Map<String, RuntimeFileApi> _fileApisByStateDirectory;
  final List<_GenerationStartRequest> _pending = <_GenerationStartRequest>[];
  bool _drainScheduled = false;
  bool _draining = false;

  Future<void> enforceBridgeOwnership() => _attemptBatch(attempt: 1, batch: const []);

  Stream<PluginGenerationStartEvent> start({
    required PluginRuntimeRegistration registration,
    required StartAbortSignal startAborted,
  }) {
    late final StreamController<PluginGenerationStartEvent> controller;
    controller = StreamController<PluginGenerationStartEvent>(
      onListen: () {
        _pending.add(
          _GenerationStartRequest(
            registration: registration,
            startAborted: startAborted,
            controller: controller,
          ),
        );
        _scheduleDrain();
      },
    );
    return controller.stream;
  }

  void _scheduleDrain() {
    if (_drainScheduled || _draining) return;
    _drainScheduled = true;
    scheduleMicrotask(_drainPending);
  }

  Future<void> _drainPending() async {
    _drainScheduled = false;
    if (_draining || _pending.isEmpty) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final batch = List<_GenerationStartRequest>.of(_pending);
        _pending.clear();
        try {
          await _attemptBatch(attempt: 1, batch: batch);
        } on Object catch (error, stackTrace) {
          for (final request in batch) {
            request.controller.addError(error, stackTrace);
          }
        } finally {
          for (final request in batch) {
            await request.controller.close();
          }
        }
      }
    } finally {
      _draining = false;
      if (_pending.isNotEmpty) _scheduleDrain();
    }
  }

  Future<void> _attemptBatch({
    required int attempt,
    required List<_GenerationStartRequest> batch,
  }) {
    return _startupMutexRepository.withLock<void>(
      bridgePid: _currentBridgeIdentity.pid,
      bridgeStartMarker: _currentBridgeIdentity.startMarker,
      onLockAcquired: () async {
        Log.d("acquired startup lock");
        final resolution = await _bridgeInstanceService.enforceSingleLiveBridge(
          currentPid: _currentBridgeIdentity.pid,
        );
        switch (resolution.status) {
          case BridgeInstanceResolutionStatus.allowed:
            final startSettlements = <Future<void>>[];
            for (final request in batch) {
              try {
                final host = await _buildHost(request: request, resolution: resolution);
                await for (final event in request.registration.descriptor.ensureRuntime(host: host)) {
                  request.controller.add(PluginGenerationProvisionProgress(event: event));
                  if (event case ProvisionReady(:final binaryPath)) {
                    host.provisionedRuntimePath = binaryPath;
                  }
                }
                startSettlements.add(
                  _settleDescriptorStart(
                    request: request,
                    start: request.registration.descriptor.start(host),
                  ),
                );
              } on PluginStartAbortedException catch (error, stackTrace) {
                request.controller.addError(error, stackTrace);
              } on Object catch (error, stackTrace) {
                request.controller.addError(
                  PluginGenerationStartFailedException(
                    pluginId: request.registration.descriptor.id,
                    cause: error,
                  ),
                  stackTrace,
                );
              }
            }
            await Future.wait(startSettlements);
          case BridgeInstanceResolutionStatus.declined:
            throw const BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge is already running and replacement was declined.",
            );
          case BridgeInstanceResolutionStatus.nonInteractive:
            throw const BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge is already running and this session is non-interactive.",
            );
        }
      },
      onLockRejected: (rejection) async {
        final lock = rejection.lock;
        final holderMatch = rejection.holderMatch;
        if (lock == null || holderMatch == null) {
          throw BridgeRuntimeServerException(
            "Startup aborted because another Sesori bridge startup is already in progress. If this persists, delete ${rejection.lockFilePath} and retry.",
          );
        }
        final status = await _bridgeInstanceService.resolveStartupLockContention(
          lock: lock,
          holder: holderMatch,
          currentPid: _currentBridgeIdentity.pid,
        );
        switch (status) {
          case BridgeInstanceResolutionStatus.allowed:
            if (attempt < 2) return _attemptBatch(attempt: attempt + 1, batch: batch);
            throw const BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge startup is still in progress after attempting replacement.",
            );
          case BridgeInstanceResolutionStatus.declined:
            throw const BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge startup is already in progress and replacement was declined.",
            );
          case BridgeInstanceResolutionStatus.nonInteractive:
            throw BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge startup is already in progress and this session is non-interactive. Bridge pid ${holderMatch.identity.pid} holds ${rejection.lockFilePath}; kill that process or delete the file to recover.",
            );
        }
      },
    );
  }

  Future<void> _settleDescriptorStart({
    required _GenerationStartRequest request,
    required Future<BridgePlugin> start,
  }) async {
    try {
      request.controller.add(
        PluginGenerationStarted(plugin: await start),
      );
    } on PluginStartAbortedException catch (error, stackTrace) {
      request.controller.addError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      request.controller.addError(
        PluginGenerationStartFailedException(
          pluginId: request.registration.descriptor.id,
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<BridgePluginHostImpl> _buildHost({
    required _GenerationStartRequest request,
    required BridgeInstanceResolution resolution,
  }) async {
    final descriptor = request.registration.descriptor;
    final expectedStateDirectory = pluginStateDirectoryPath(
      paths: _managedRuntimePaths,
      pluginId: descriptor.id,
      stateStorage: descriptor.stateStorage,
    );
    final stateDirectory = request.registration.stateDirectory;
    if (stateDirectory != expectedStateDirectory) {
      throw StateError('Plugin "${descriptor.id}" registration has an unexpected state directory.');
    }
    await io.Directory(stateDirectory).create(recursive: true);
    final fileApi = _fileApisByStateDirectory.putIfAbsent(
      stateDirectory,
      () => RuntimeFileApi(runtimeDirectory: stateDirectory),
    );
    return BridgePluginHostImpl(
      config: request.registration.config,
      stateDirectory: stateDirectory,
      environment: _environment,
      clock: _clock,
      startAborted: request.startAborted,
      bridge: BridgeHostInfoImpl(
        identity: _currentBridgeIdentity,
        ownerSessionId: _ownerSessionId,
        terminatedBridgeIdentities: resolution.terminatedBridges,
        processRepository: _processRepository,
      ),
      processes: BridgeHostProcessService(
        processStarter: io.Process.start,
        processRepository: _processRepository,
        clock: _clock,
        currentUser: _currentUser,
        isWindows: io.Platform.isWindows,
        platform: io.Platform.operatingSystem,
      ),
      ports: const BridgeHostPortService(loopbackPortApi: LoopbackPortApi()),
      store: BridgeHostJsonStore(fileApi: fileApi),
    );
  }
}

class _GenerationStartRequest {
  const _GenerationStartRequest({
    required this.registration,
    required this.startAborted,
    required this.controller,
  });

  final PluginRuntimeRegistration registration;
  final StartAbortSignal startAborted;
  final StreamController<PluginGenerationStartEvent> controller;
}
