import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_process_service.dart";
import "managed_runtime_monitor.dart";
import "managed_runtime_status_reporter.dart";

abstract interface class ManagedRuntimeApi() {
  Stream<PluginWorkState> get workState;

  PluginWorkState get currentWorkState;

  Future<Set<String>> interruptActiveWork({required Duration budget});

  Future<void> dispose();
}

class ManagedRuntimeBridgePlugin<R, A extends BridgePluginApi>({
  @override required final A api,
  required final ManagedRuntimeApi managedApi,
  required final ManagedRuntimeStatusReporter reporter,
  required final ManagedRuntimeMonitor<R> monitor,
  required final ManagedProcessService<R> service,
  required final R? ownedRecord,
  required final PluginDiagnostics diagnostics,
  required final String displayName,
  required final String logContext,
  required final bool interruptOwnedOnly,
  /// Backend-specific warm-up for [BridgePlugin.onStarted], or null when this
  /// plugin has nothing to warm. Required so adding a managed plugin states its
  /// startup intent rather than inheriting one by omission. Nothing waits on it
  /// and the runtime never retries it.
  required final Future<void> Function()? onStartWarmUp,
}) implements BridgePlugin {
  Future<void>? _shutdown;

  PluginStatusController get _status => reporter.status;

  R? get _currentOwnedRecord => monitor.currentHandle?.record ?? ownedRecord;

  @override
  Stream<PluginStatus> get status => _status.stream;

  @override
  PluginStatus get currentStatus => _status.current;

  @override
  Stream<PluginWorkState> get workState => managedApi.workState;

  @override
  PluginWorkState get currentWorkState => managedApi.currentWorkState;

  @override
  PluginDiagnostics describe() => diagnostics;

  @override
  Future<void> onStarted() async {
    await onStartWarmUp?.call();
  }

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) {
    if (interruptOwnedOnly && _currentOwnedRecord == null) {
      Log.d("[$logContext] server is not bridge-owned; skipping active-work interruption");
      return Future<Set<String>>.value(const <String>{});
    }
    return managedApi.interruptActiveWork(budget: budget);
  }

  @override
  Future<void> shutdown({required Duration? budget}) => _shutdown ??= _shutdownNow();

  Future<void> _shutdownNow() async {
    final sw = Stopwatch()..start();
    Log.d("[shutdown] $displayName plugin stop begin (mode=${ownedRecord == null ? "attached" : "managed"})");
    reporter.dispose();
    if (!_status.isClosed && _status.current is! PluginStopped) {
      _status.trySet(const PluginStopping());
    }
    try {
      Object? primaryError;
      StackTrace? primaryStackTrace;

      try {
        await monitor.disarm();
        Log.v("[shutdown] $displayName monitor disarmed (+${sw.elapsedMilliseconds}ms)");
      } on Object catch (error, stackTrace) {
        Log.e("[$logContext] monitor disarm failed", error, stackTrace);
        primaryError = error;
        primaryStackTrace = stackTrace;
      }

      try {
        await managedApi.dispose();
        Log.v("[shutdown] $displayName api disposed (+${sw.elapsedMilliseconds}ms)");
      } on Object catch (error, stackTrace) {
        Log.e("[$logContext] plugin api dispose failed", error, stackTrace);
        primaryError ??= error;
        primaryStackTrace ??= stackTrace;
      }

      final record = _currentOwnedRecord;
      if (record != null) {
        try {
          await service.stopOwnedRuntime(record: record);
          Log.v("[shutdown] $displayName owned runtime stopped (+${sw.elapsedMilliseconds}ms)");
        } on Object catch (error, stackTrace) {
          Log.e("[$logContext] stop owned runtime failed", error, stackTrace);
          primaryError ??= error;
          primaryStackTrace ??= stackTrace;
        }
      } else {
        Log.v("[shutdown] $displayName has no owned runtime to stop (attach mode)");
      }

      if (primaryError != null && primaryStackTrace != null) {
        Error.throwWithStackTrace(primaryError, primaryStackTrace);
      }
    } finally {
      if (!_status.isClosed) {
        _status.trySet(const PluginStopped());
      }
      Log.d("[shutdown] $displayName plugin stop complete (${sw.elapsedMilliseconds}ms total)");
    }
  }
}
