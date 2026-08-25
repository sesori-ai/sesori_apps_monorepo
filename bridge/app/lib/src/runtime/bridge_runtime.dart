import "dart:async";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show FailureReporter;

import "../api/database/database.dart";
import "../api/database/history/chat_history_database.dart";
import "../bridge/device_canvas/ipc_server.dart";
import "../bridge/device_canvas/rendezvous_repository.dart";
import "../debug_server.dart";
import "../foundation/bandwidth_tracker.dart";
import "../listeners/plugin_catalog_hydration_listener.dart";
import "../orchestrator.dart";
import "../routing/bridge_restart_dispatcher.dart";
import "../routing/routed_request_dispatcher.dart";
import "../services/catalog_import_service.dart";
import "bridge_shutdown_coordinator.dart";

class BridgeRuntime({
  required final AppDatabase _database,
  required final ChatHistoryDatabase _chatHistoryDatabase,
  required final FailureReporter _failureReporter,
  required final OrchestratorComposition _composition,
}) {
  final BridgeRestartDispatcher _restartDispatcher = _composition.restartDispatcher;
  final RoutedRequestDispatcher _routedRequestDispatcher = _composition.routedRequestDispatcher;
  DeviceCanvasIpcServer? _deviceCanvasIpcServer;
  StreamSubscription<String>? _bridgeRegistrationSubscription;
  Future<void> _deviceCanvasIpcRotation = Future<void>.value();
  Future<void>? _closeFuture;
  bool _closing = false;

  OrchestratorSession get session => _composition.session;
  CatalogImportService get catalogImportService => _composition.catalogImportService;
  PluginCatalogHydrationListener get catalogHydrationListener => _composition.catalogHydrationListener;

  Future<void> reconcileDeletedSessionStorage() {
    return _composition.deletedSessionStorageCleanupService.reconcile();
  }

  Future<void> reconcileChatHistory() {
    return _composition.chatHistoryReconcileService.reconcile();
  }

  Future<void> cleanupDeviceCanvasClaimsOnStartup({required String bridgeId}) {
    return _composition.deviceCanvasClaimService.cleanupForStartup(bridgeId: bridgeId);
  }

  Future<void> startDeviceCanvasIpcServer({
    required String dataDirectory,
    required String bridgeId,
    required String processGeneration,
    required Stream<String> bridgeRegistrations,
  }) async {
    _deviceCanvasIpcServer = await _startDeviceCanvasIpcServer(
      rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: dataDirectory),
      bridgeId: bridgeId,
      processGeneration: processGeneration,
    );
    _bridgeRegistrationSubscription = bridgeRegistrations.listen(
      (nextBridgeId) => _enqueueDeviceCanvasIpcRotation(dataDirectory: dataDirectory, bridgeId: nextBridgeId),
      onError: (Object error, StackTrace stackTrace) => Log.w(
        "Device Canvas IPC bridge registration stream failed",
        error,
        stackTrace,
      ),
    );
  }

  Future<void> get deviceCanvasIpcLifecycleIdle => _deviceCanvasIpcRotation;

  Future<DeviceCanvasIpcServer> _startDeviceCanvasIpcServer({
    required DeviceCanvasRendezvousRepository rendezvousRepository,
    required String bridgeId,
    required String processGeneration,
  }) async {
    final server = DeviceCanvasIpcServer(
      rendezvousRepository: rendezvousRepository,
      bridgeId: bridgeId,
      processGeneration: processGeneration,
      claimService: _composition.deviceCanvasClaimService,
      integrationState: _composition.deviceCanvasIntegrationState,
    );
    await server.start();
    return server;
  }

  void _enqueueDeviceCanvasIpcRotation({required String dataDirectory, required String bridgeId}) {
    if (_closing) return;
    _deviceCanvasIpcRotation = _deviceCanvasIpcRotation.then((_) {
      if (_closing) return Future<void>.value();
      return _rotateDeviceCanvasIpcServer(dataDirectory: dataDirectory, bridgeId: bridgeId);
    });
  }

  Future<void> _rotateDeviceCanvasIpcServer({required String dataDirectory, required String bridgeId}) async {
    final oldServer = _deviceCanvasIpcServer;
    _deviceCanvasIpcServer = null;
    try {
      await oldServer?.dispose();
    } on Object catch (error, stackTrace) {
      Log.w("failed to dispose old Device Canvas IPC server during bridge registration rotation", error, stackTrace);
    }
    try {
      _deviceCanvasIpcServer = await _startDeviceCanvasIpcServer(
        rendezvousRepository: DeviceCanvasRendezvousRepository(dataDirectory: dataDirectory),
        bridgeId: bridgeId,
        processGeneration: "$pid:${DateTime.now().microsecondsSinceEpoch}",
      );
    } on Object catch (error, stackTrace) {
      Log.w("failed to rotate Device Canvas IPC server after bridge registration", error, stackTrace);
    }
  }

  BandwidthTracker createBandwidthTracker() {
    return BandwidthTracker(bytesSent: session.bytesSent);
  }

  DebugServer createDebugServer({required int port}) {
    return DebugServer(
      localWireEvents: session.localWireEvents,
      routedRequestDispatcher: _routedRequestDispatcher,
      port: port,
      failureReporter: _failureReporter,
      restartDispatcher: _restartDispatcher,
    );
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closing = true;
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> step(Future<void> Function() dispose) async {
      try {
        await dispose();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await step(_restartDispatcher.dispose);
    await step(() => _bridgeRegistrationSubscription?.cancel() ?? Future<void>.value());
    _bridgeRegistrationSubscription = null;
    await step(() => _deviceCanvasIpcRotation);
    await step(() => _deviceCanvasIpcServer?.dispose() ?? Future<void>.value());
    _deviceCanvasIpcServer = null;
    await step(_composition.deviceCanvasIntegrationState.dispose);
    await step(_composition.deviceCanvasClaimService.dispose);
    await step(_composition.sessionUnseenService.dispose);
    await step(_composition.sessionViewTracker.dispose);
    await step(_composition.projectViewTracker.dispose);
    await step(_composition.sessionRepository.dispose);
    await step(_composition.catalogHydrationListener.dispose);
    await step(_composition.catalogImportService.dispose);
    await step(_database.close);
    await step(_chatHistoryDatabase.close);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

Future<void> startDebugServerIfRequested({
  required int? debugPort,
  required BridgeRuntime runtime,
  required BridgeShutdownCoordinator shutdownCoordinator,
}) async {
  if (debugPort == null) return;

  final bandwidthTracker = runtime.createBandwidthTracker();
  shutdownCoordinator.add(disposable: bandwidthTracker.dispose);

  try {
    final debugServer = runtime.createDebugServer(port: debugPort);
    await debugServer.start();
    // Registered only once the server is listening, so the coordinator's
    // phase closures never capture a half-started server.
    shutdownCoordinator
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: debugServer.beginShutdown,
      )
      ..addPhase(
        phase: BridgeShutdownPhase.drain,
        action: debugServer.drain,
      );
  } on Object catch (error, stackTrace) {
    Log.w("failed to start debug server", error, stackTrace);
  }
}

void registerSignalHandlers({
  required OrchestratorSession session,
  required CompositeSubscription subscriptions,
}) {
  var shutdownSignalCount = 0;
  void handleShutdownSignal(String name) {
    shutdownSignalCount++;
    if (shutdownSignalCount >= 2) {
      Log.e("[shutdown] $name received (#$shutdownSignalCount) - forcing immediate exit");
      exit(1);
    }
    Log.i("[shutdown] $name received (#$shutdownSignalCount) - cancelling session");
    unawaited(session.cancel());
  }

  ProcessSignal.sigint.watch().listen((_) => handleShutdownSignal("SIGINT")).addTo(subscriptions);
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => handleShutdownSignal("SIGTERM")).addTo(subscriptions);
  }
}
