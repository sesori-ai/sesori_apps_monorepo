import "dart:async";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show FailureReporter;

import "../../api/database/database.dart";
import "../../server/services/bridge_restart_service.dart";
import "../../services/catalog_import_service.dart";
import "../bandwidth_tracker.dart";
import "../debug_server.dart";
import "../orchestrator.dart";
import "bridge_shutdown_coordinator.dart";

class BridgeRuntime {
  BridgeRuntime({
    required AppDatabase database,
    required FailureReporter failureReporter,
    required BridgeRestartService restartService,
    required OrchestratorComposition composition,
  }) : _database = database,
       _failureReporter = failureReporter,
       _restartService = restartService,
       _composition = composition;

  final AppDatabase _database;
  final FailureReporter _failureReporter;
  final BridgeRestartService _restartService;
  final OrchestratorComposition _composition;
  Future<void>? _closeFuture;

  OrchestratorSession get session => _composition.session;
  CatalogImportService get catalogImportService => _composition.catalogImportService;

  BandwidthTracker createBandwidthTracker() {
    return BandwidthTracker(bytesSent: session.bytesSent);
  }

  DebugServer createDebugServer({required int port}) {
    return DebugServer(
      localWireEvents: session.localWireEvents,
      router: session.router,
      port: port,
      failureReporter: _failureReporter,
      restartService: _restartService,
      restartHandoff: session.handleRestartHandoff,
    );
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
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

    await step(_composition.sessionUnseenService.dispose);
    await step(_composition.sessionViewTracker.dispose);
    await step(_composition.sessionRepository.dispose);
    await step(_composition.catalogImportService.dispose);
    await step(_database.close);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }
}

Future<DebugServer?> startDebugServerIfRequested({
  required int? debugPort,
  required BridgeRuntime runtime,
  required BridgeShutdownCoordinator shutdownCoordinator,
}) async {
  if (debugPort == null) return null;

  final bandwidthTracker = runtime.createBandwidthTracker();
  shutdownCoordinator.add(disposable: bandwidthTracker.dispose);

  try {
    final debugServer = runtime.createDebugServer(port: debugPort);
    await debugServer.start();
    return debugServer;
  } on Object catch (error, stackTrace) {
    Log.w("failed to start debug server", error, stackTrace);
    return null;
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
