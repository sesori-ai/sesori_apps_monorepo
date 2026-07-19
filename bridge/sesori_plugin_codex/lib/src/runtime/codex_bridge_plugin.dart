import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show ManagedProcessService, ManagedRuntimeMonitor;

import "codex_managed_api.dart";
import "codex_ownership_record.dart";
import "codex_status_reporter.dart";

/// Live-plugin wrapper for the managed Codex flow.
///
/// Pairs the stable [api] (the codex WebSocket transport) with the lifecycle
/// surface: a [PluginStatusController] fed by both the transport (via
/// [CodexRuntimeStatusReporter]) and the exit monitor, plus an ordered,
/// idempotent [shutdown].
class CodexBridgePlugin implements BridgePlugin {
  CodexBridgePlugin({
    required this.api,
    required CodexRuntimeStatusReporter reporter,
    required ManagedRuntimeMonitor<CodexOwnershipRecord> monitor,
    required ManagedProcessService<CodexOwnershipRecord> service,
    required CodexOwnershipRecord? ownedRecord,
    required this.port,
    required this.serverUrl,
  }) : _reporter = reporter,
       _monitor = monitor,
       _service = service,
       _ownedRecord = ownedRecord;

  @override
  final CodexManagedApi api;

  final int port;
  final String serverUrl;

  final CodexRuntimeStatusReporter _reporter;
  final ManagedRuntimeMonitor<CodexOwnershipRecord> _monitor;
  final ManagedProcessService<CodexOwnershipRecord> _service;
  final CodexOwnershipRecord? _ownedRecord;

  Future<void>? _shutdown;

  PluginStatusController get _status => _reporter.status;

  @override
  Stream<PluginStatus> get status => _status.stream;

  @override
  PluginStatus get currentStatus => _status.current;

  @override
  Stream<PluginWorkState> get workState => api.workState;

  @override
  PluginWorkState get currentWorkState => api.currentWorkState;

  @override
  PluginDiagnostics describe() {
    return PluginDiagnostics(
      pluginId: "codex",
      endpoint: serverUrl,
      details: {
        "port": "$port",
        "mode": _ownedRecord == null ? "attached" : "managed",
      },
    );
  }

  /// Stops the plugin in order: disarm the monitor (so the child's deliberate
  /// exit is never mistaken for a crash), tear down the api, then stop the owned
  /// `codex app-server` process (when this bridge owns one). Idempotent —
  /// repeated calls return the same future — and safe before/after
  /// [BridgePluginApi.dispose].
  ///
  /// [budget] is accepted but not subdivided: the stop path keeps its own
  /// pacing (graceful signal, wait, force).
  @override
  Future<void> shutdown({required Duration? budget}) => _shutdown ??= _shutdownNow();

  Future<void> _shutdownNow() async {
    final sw = Stopwatch()..start();
    Log.d("[shutdown] Codex plugin stop begin (mode=${_ownedRecord == null ? "attached" : "managed"})");
    _reporter.dispose();
    if (!_status.isClosed && _status.current is! PluginStopped) {
      _status.trySet(const PluginStopping());
    }
    try {
      // Each teardown step is independently guarded so a failure in one never
      // skips the others — in particular, a `disarm()` throw must not leave the
      // owned `codex app-server` child running (orphaned). `on Object` so a
      // thrown `Error` (not just `Exception`) can't short-circuit cleanup.
      // Preserve the first meaningful teardown error and rethrow it after all
      // steps have run, so a hung/failed shutdown still surfaces.
      Object? primaryError;
      StackTrace? primaryStackTrace;

      try {
        // Disarm before signaling the child so its deliberate exit is not
        // mistaken for a crash (no spurious PluginFailed).
        await _monitor.disarm();
        Log.v("[shutdown] Codex monitor disarmed (+${sw.elapsedMilliseconds}ms)");
      } on Object catch (error, stackTrace) {
        Log.e("[codex] monitor disarm failed: $error");
        primaryError = error;
        primaryStackTrace = stackTrace;
      }

      try {
        await api.dispose();
        Log.v("[shutdown] Codex api disposed (+${sw.elapsedMilliseconds}ms)");
      } on Object catch (error, stackTrace) {
        primaryError ??= error;
        primaryStackTrace ??= stackTrace;
        Log.e("[codex] plugin api dispose failed: $error");
      }

      // The monitor's current handle reflects any restart-adopted child; fall
      // back to the record captured at start. The owned server must be stopped
      // even when api teardown failed above.
      final record = _monitor.currentHandle?.record ?? _ownedRecord;
      if (record != null) {
        try {
          await _service.stopOwnedRuntime(record: record);
          Log.v("[shutdown] Codex owned runtime stopped (+${sw.elapsedMilliseconds}ms)");
        } on Object catch (error, stackTrace) {
          Log.e("[codex] stop owned runtime failed: $error");
          primaryError ??= error;
          primaryStackTrace ??= stackTrace;
        }
      } else {
        Log.v("[shutdown] Codex has no owned runtime to stop (attach mode)");
      }

      if (primaryError != null) {
        Error.throwWithStackTrace(primaryError, primaryStackTrace!);
      }
    } finally {
      if (!_status.isClosed) {
        _status.trySet(const PluginStopped());
      }
      Log.d("[shutdown] Codex plugin stop complete (${sw.elapsedMilliseconds}ms total)");
    }
  }
}
