import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";
import "../repositories/models/catalog_import_result.dart";
import "../repositories/models/plugin_management_result.dart";
import "../repositories/plugin_repository.dart";
import "models/catalog_rescan_state.dart";
import "plugin_management_service.dart";

/// How long a settled rescan row stays before clearing itself.
const _settledVisibleFor = Duration(seconds: 4);

/// Drives catalog rescans and publishes them as one aggregate row.
///
/// The service owns a single *operation*: the set of harness ids it is
/// currently tracking, plus whether this client saw the whole thing. An
/// operation is `owned` when this client dispatched every member's start, and
/// `observed` when it learned of the run from the recovery read or from an
/// unsolicited progress event. Only an owned operation reports a terminal
/// summary; an observed one settles quietly, because the client cannot know
/// what happened to members it never saw.
///
/// Naming the operation is what keeps membership, settlement and the post-run
/// refresh consistent with one another instead of being three independent
/// rules.
@lazySingleton
class CatalogRescanService({
  required final PluginRepository _pluginRepository,
  required final PluginManagementService _managementService,
  required final ConnectionService _connectionService,
}) with Disposable {
  this {
    _subscriptions
      ..add(_connectionService.status.listen(_onConnectionStatus))
      ..add(_connectionService.events.listen(_onSseEvent))
      ..add(_managementService.snapshots.listen(_onManagementSnapshot));
    // Resolved lazily, so the connection is often already up by the time this
    // exists and no false-to-true transition will ever arrive to trigger the
    // recovery read.
    if (_connected) unawaited(_recoverInFlight());
  }

  final BehaviorSubject<CatalogRescanState> _state = BehaviorSubject.seeded(
    const CatalogRescanState.idle(),
  );
  final StreamController<void> _catalogChanged = StreamController<void>.broadcast(sync: true);
  final CompositeSubscription _subscriptions = CompositeSubscription();

  /// Latest progress per harness in the live operation. Cleared whenever an
  /// operation opens or the state resets, never on a join.
  final Map<String, CatalogImportProgress> _progressByPluginId = {};

  /// The live operation's members, or empty when none is live.
  final Set<String> _members = {};

  /// Display names and runtime states from the current bridge's latest
  /// management snapshot.
  Map<String, String> _displayNames = const {};
  Map<String, PluginRuntimeState> _runtimeStates = const {};

  /// Bridge identity whose management snapshot opened the live operation.
  /// Runtime state can describe its phases only while this still matches.
  String? _operationBridgeId;

  /// True when the live operation was discovered rather than started here.
  bool _observed = false;

  Timer? _clearTimer;
  bool _connected = _connectionService.currentStatus is ConnectionConnected;
  String? _activeBridgeId;
  bool _disposed = false;

  ValueStream<CatalogRescanState> get state => _state.stream;

  /// Fires after an observed import publishes list-visible catalog rows.
  ///
  /// List cubits use this durable-data signal rather than the progress row's
  /// lifecycle, because an observed run settles without a summary and a
  /// completion can arrive for a harness outside the live operation. Automatic
  /// hydration markers complete with zero published rows and do not invalidate
  /// the lists.
  Stream<void> get catalogChanged => _catalogChanged.stream;

  /// Rescans every harness this bridge can import from.
  ///
  /// Every manual refresh calls this, so a bridge with nothing to import from
  /// settles silently and the refresh is only a reload, which reports its own
  /// outcome: no connection, a bridge older than v1.7.0 without a harness list,
  /// a failed harness list, or no routable harness.
  Future<void> startAll() async {
    if (_disposed) return;
    // Management snapshots can outlive the connection that produced them.
    // Check connectivity first so stale metadata cannot start a rescan on a
    // bridge that is no longer connected.
    if (_connectionService.currentStatus is! ConnectionConnected) return;
    // CatalogRescanService is lazy and can first exist at the refresh.
    // Bootstrap one authoritative management read before deciding there is no
    // harness; PluginManagementService fences this refresh to its connection
    // and bridge identity.
    if (_managementService.snapshots.valueOrNull
        case PluginManagementLoadResultLoading() || PluginManagementLoadResultFailure() || null) {
      await _managementService.refresh();
      if (_disposed) return;
      // The connection can drop while the authoritative refresh is in flight.
      if (_connectionService.currentStatus is! ConnectionConnected) return;
    }
    switch (_managementService.snapshots.valueOrNull) {
      case PluginManagementLoadResultSupported(:final response):
        final pluginIds = [
          for (final plugin in response.plugins)
            if (plugin.runtimeState.isRoutable) plugin.setup.id,
        ];
        if (pluginIds.isEmpty) return;
        await _start(pluginIds: pluginIds, operationBridgeId: response.bridgeId);
      case PluginManagementLoadResultFailure(:final error):
        // The refresh carries on as a reload, so keep why it did not import.
        logw("Catalog rescan skipped because the harness list could not be read", error);
      case PluginManagementLoadResultUnsupported() || PluginManagementLoadResultLoading() || null:
        return;
    }
  }

  @override
  Future<void> onDispose() async {
    if (_disposed) return;
    _disposed = true;
    _clearTimer?.cancel();
    await _subscriptions.dispose();
    await _state.close();
    await _catalogChanged.close();
  }

  Future<void> _start({
    required List<String> pluginIds,
    required String? operationBridgeId,
  }) async {
    _openOrJoin(
      pluginIds: pluginIds,
      observed: false,
      operationBridgeId: operationBridgeId,
    );
    await Future.wait([
      for (final pluginId in pluginIds)
        _pluginRepository.startCatalogImport(pluginId: pluginId).then((outcome) {
          _applyStartOutcome(pluginId: pluginId, outcome: outcome);
          // A rejected start can change focus/counts while another response
          // is still pending. Do not hold that update behind the batch wait.
          _publishLive();
        }),
    ]);
    if (_disposed) return;
    // Two conditions, not one. `_members.isEmpty` alone is also true when the
    // operation closed while this dispatch was awaiting — settled from SSE or
    // reset by a disconnect — and closing it again would erase a settled row
    // early and fire a second refresh. `isLive` is the cheap way to tell those
    // apart, because _openOrJoin always publishes a live state before dispatch.
    if (_members.isEmpty && _state.value.isLive) {
      // Every member was refused, so nothing runs, and the refresh that asked
      // for this settles silently into its reload.
      _closeOperation(const CatalogRescanState.idle());
      return;
    }
    _publishLive();
    _settleIfComplete();
  }

  /// Applies one dispatch outcome to membership.
  ///
  /// A harness joins on dispatch rather than on acknowledgement, so a timeout
  /// or lost response — which the relay can raise *after* the request landed —
  /// keeps it in the operation. Only an answer from the bridge removes it.
  void _applyStartOutcome({
    required String pluginId,
    required CatalogImportMutationResult outcome,
  }) {
    switch (outcome) {
      case CatalogImportMutationAccepted():
        return;
      // The bridge cannot import from this harness right now, so the fan-out
      // skips it.
      case CatalogImportMutationNotFound() || CatalogImportMutationUnavailable():
        _members.remove(pluginId);
      case CatalogImportMutationUncertain(:final error):
        // The request may well have landed, so the harness stays a member and
        // settles from its own progress event rather than being written off.
        logw("Catalog rescan start could not be confirmed for $pluginId", error);
      case CatalogImportMutationFailure(:final error):
        // The bridge answered and refused, so this harness is settled and
        // counts against the run. Retained locally because the failure may
        // never have reached the bridge's own log.
        logw("Catalog rescan could not be started for $pluginId", error);
        _progressByPluginId[pluginId] = CatalogImportProgress.failed(
          pluginId: pluginId,
          message: "start rejected",
        );
    }
  }

  void _openOrJoin({
    required List<String> pluginIds,
    required bool observed,
    required String? operationBridgeId,
  }) {
    if (_members.isEmpty) {
      _clearTimer?.cancel();
      _clearTimer = null;
      _progressByPluginId.clear();
      _operationBridgeId = operationBridgeId;
      _observed = observed;
    } else if (observed) {
      // A harness someone else started joined a run this client owned. The
      // operation can no longer claim it saw every member, so it stops being
      // able to summarise itself.
      _observed = true;
    }
    _members.addAll(pluginIds);
    _publishLive();
  }

  void _onSseEvent(SseEvent event) {
    if (_disposed) return;
    if (event.data case SesoriCatalogImportProgress(:final progress)) {
      _applyProgress(progress);
    }
  }

  void _applyProgress(CatalogImportProgress progress) {
    // The counts are the rows the import wrote (totals on a bridge up to
    // v1.10.1). Imports are non-destructive, so a completion that wrote
    // nothing leaves every list row unchanged. Announce a committed
    // snapshot before the operation bookkeeping below, which drops a
    // completion for a harness outside the live operation: its rows changed
    // all the same.
    if (progress case CatalogImportCompleted(:final projectsImported, :final sessionsImported)
        when (projectsImported > 0 || sessionsImported > 0) && !_catalogChanged.isClosed) {
      _catalogChanged.add(null);
    }

    final pluginId = progress.pluginId;
    // The row and the alert name only the harness; the bridge's own message is
    // kept here, in the local log.
    if (progress case CatalogImportFailed(:final message)) logw("Catalog import failed for $pluginId: $message");
    if (!_members.contains(pluginId)) {
      // A rescan someone else started, seen live. Adopt it so its imported
      // sessions still reach the lists, but as an observed operation, which
      // claims no summary.
      if (_isTerminal(progress)) return;
      _openOrJoin(
        pluginIds: [pluginId],
        observed: true,
        operationBridgeId: _activeBridgeId,
      );
    }
    // Another client cancelled a member of this run. That is intervention, not
    // failure, and it means this client no longer saw the whole operation, so
    // it settles quietly instead of publishing a failure row.
    if (progress is CatalogImportCancelled) _observed = true;
    // A member that already settled and is reporting progress again was
    // restarted by someone else. Its second run is not this operation's to
    // summarise, so the aggregate stops claiming one — the same rule as a
    // harness joining from outside, which this path bypasses.
    final previous = _progressByPluginId[pluginId];
    if (previous != null && _isTerminal(previous) && !_isTerminal(progress)) {
      _observed = true;
    }
    _progressByPluginId[pluginId] = progress;
    if (_isTerminal(progress)) {
      _settleIfComplete();
      // Still running: advance to the next unfinished member in operation
      // order, rather than leaving the row naming the one that just finished.
      if (_members.isNotEmpty) _publishLive();
      return;
    }
    // Keep background progress for handoff without rebuilding the lists for
    // each hidden enumeration or phase change.
    if (pluginId == _focusedPluginId()) _publishLive();
  }

  void _publishLive() {
    if (_members.isEmpty) return;
    final pluginIds = Set<String>.unmodifiable(_members);
    final focusedPluginId = _focusedPluginId();
    if (focusedPluginId == null) return;
    final finishedHarnessCount = _finishedHarnessCount();
    final active = _progressByPluginId[focusedPluginId];
    if (active != null) {
      final pluginName = _displayName(pluginId: focusedPluginId);
      final next = switch (active) {
        CatalogImportEnumerating(:final sessionsSeen)
            when sessionsSeen == 0 && _isConfirmedStarting(pluginId: focusedPluginId) =>
          CatalogRescanState.starting(
            activePluginName: pluginName,
            finishedHarnessCount: finishedHarnessCount,
            pluginIds: pluginIds,
          ),
        CatalogImportEnumerating(:final sessionsSeen) => CatalogRescanState.reading(
          activePluginName: pluginName,
          sessionsSeen: sessionsSeen,
          finishedHarnessCount: finishedHarnessCount,
          pluginIds: pluginIds,
        ),
        CatalogImportCommitting() => CatalogRescanState.saving(
          activePluginName: pluginName,
          finishedHarnessCount: finishedHarnessCount,
          pluginIds: pluginIds,
        ),
        // Unreachable: _focusedPluginId returns only missing or non-terminal
        // statuses. The exhaustive switch keeps any new transport phase
        // visible here.
        CatalogImportCompleted() ||
        CatalogImportCancelled() ||
        CatalogImportFailed() => throw StateError("Terminal catalog progress cannot be active"),
      };
      _publish(next);
      return;
    }

    final pluginName = _displayName(pluginId: focusedPluginId);
    _publish(
      _isConfirmedStarting(pluginId: focusedPluginId)
          ? CatalogRescanState.starting(
              activePluginName: pluginName,
              finishedHarnessCount: finishedHarnessCount,
              pluginIds: pluginIds,
            )
          : CatalogRescanState.preparingOne(
              pendingPluginName: pluginName,
              finishedHarnessCount: finishedHarnessCount,
              pluginIds: pluginIds,
            ),
    );
  }

  String _displayName({required String pluginId}) => _displayNames[pluginId] ?? pluginId;

  bool _isConfirmedStarting({required String pluginId}) =>
      _operationBridgeId != null &&
      _operationBridgeId == _activeBridgeId &&
      _runtimeStates[pluginId] == PluginRuntimeState.starting;

  /// The first member without terminal progress, preserving operation order.
  /// A missing progress event is unfinished and therefore keeps foreground
  /// focus ahead of later harnesses that have already started.
  String? _focusedPluginId() {
    for (final pluginId in _members) {
      final progress = _progressByPluginId[pluginId];
      if (progress == null || !_isTerminal(progress)) return pluginId;
    }
    return null;
  }

  int _finishedHarnessCount() {
    var finished = 0;
    for (final pluginId in _members) {
      final progress = _progressByPluginId[pluginId];
      if (progress != null && _isTerminal(progress)) finished++;
    }
    return finished;
  }

  void _settleIfComplete() {
    if (_members.isEmpty) return;
    final settledMembers = [
      for (final pluginId in _members)
        if (_progressByPluginId[pluginId] case final progress? when _isTerminal(progress)) progress,
    ];
    if (settledMembers.length < _members.length) return;

    // An operation this client did not see from the start cannot honestly
    // summarise itself: members that finished while it was away were dropped
    // by the recovery filter and cannot be recovered, because the bridge's
    // status read carries no operation identity.
    if (_observed) {
      _closeOperation(const CatalogRescanState.idle());
      return;
    }

    final succeeded = settledMembers.whereType<CatalogImportCompleted>().toList(growable: false);
    final failedPluginIds = {
      for (final progress in settledMembers)
        if (progress is! CatalogImportCompleted) progress.pluginId,
    };
    if (succeeded.isEmpty) {
      _closeOperation(CatalogRescanState.failed(failedPluginIds: failedPluginIds));
      return;
    }
    if (failedPluginIds.isNotEmpty) {
      _closeOperation(
        CatalogRescanState.partlyFailed(succeededCount: succeeded.length, failedPluginIds: failedPluginIds),
      );
      return;
    }
    _closeOperation(
      CatalogRescanState.succeeded(harnessCount: succeeded.length, counts: _sumCounts(succeeded)),
    );
  }

  /// Sums across every succeeded harness rather than reporting whichever
  /// finished last. Falls back to totals when any harness omitted its delta,
  /// because a delta missing one contribution would understate the result while
  /// still reading as authoritative.
  CatalogRescanCounts _sumCounts(List<CatalogImportCompleted> completions) {
    if (completions.every((c) => c.newItems != null)) {
      var projects = 0;
      var sessions = 0;
      for (final completion in completions) {
        if (completion.newItems case final newItems?) {
          projects += newItems.projects;
          sessions += newItems.sessions;
        }
      }
      return CatalogRescanCounts.delta(newProjects: projects, newSessions: sessions);
    }
    var projects = 0;
    var sessions = 0;
    for (final completion in completions) {
      projects += completion.projectsImported;
      sessions += completion.sessionsImported;
    }
    return CatalogRescanCounts.totals(projects: projects, sessions: sessions);
  }

  /// Ends the live operation and publishes [next].
  void _closeOperation(CatalogRescanState next) {
    _members.clear();
    _progressByPluginId.clear();
    _operationBridgeId = null;
    _observed = false;
    _publish(next);
    // The row has no Dismiss, so every result clears itself: the row fades out
    // once read, and a failure has already raised its alert.
    if (next is! CatalogRescanIdle) {
      _clearTimer?.cancel();
      _clearTimer = Timer(_settledVisibleFor, _reset);
    }
  }

  void _reset() {
    if (_disposed) return;
    _clearTimer?.cancel();
    _clearTimer = null;
    _members.clear();
    _progressByPluginId.clear();
    _operationBridgeId = null;
    _observed = false;
    _publish(const CatalogRescanState.idle());
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (_disposed) return;
    final nextConnected = status is ConnectionConnected;
    if (nextConnected == _connected) return;
    _connected = nextConnected;
    _reset();
    _activeBridgeId = null;
    _runtimeStates = const {};
    if (nextConnected) unawaited(_recoverInFlight());
  }

  void _onManagementSnapshot(PluginManagementLoadResult snapshot) {
    if (_disposed) return;
    if (snapshot is! PluginManagementLoadResultSupported) {
      // Loading, failed, and legacy snapshots cannot authoritatively describe
      // a runtime phase. Keep known names for stable fallback copy, but never
      // carry a prior bridge's `starting` attribution across them.
      _runtimeStates = const {};
      if (_members.isNotEmpty) _publishLive();
      return;
    }
    _displayNames = {
      for (final plugin in snapshot.response.plugins) plugin.setup.id: plugin.setup.displayName,
    };
    _runtimeStates = snapshot.refreshError == null
        ? {
            for (final plugin in snapshot.response.plugins) plugin.setup.id: plugin.runtimeState,
          }
        : const {};
    final bridgeId = snapshot.response.bridgeId;
    if (_activeBridgeId != null && _activeBridgeId != bridgeId) {
      _reset();
      // The recovery read fired on reconnect may have adopted the new bridge's
      // run before this identity arrived, and the reset above just discarded
      // it. Read again now that the identity is settled, or an import already
      // running here stays invisible until it ends.
      _activeBridgeId = bridgeId;
      unawaited(_recoverInFlight());
      return;
    }
    _activeBridgeId = bridgeId;
    if (_members.isNotEmpty) _publishLive();
  }

  /// Adopts a rescan that was already running when this client connected.
  ///
  /// Terminal statuses are discarded rather than adopted: the bridge keeps the
  /// last status per plugin forever, and its hydration short-circuit publishes
  /// a completion for every enabled plugin at every start, so seeding from them
  /// would announce a stale "rescan complete" on every connect.
  Future<void> _recoverInFlight() async {
    final result = await _pluginRepository.getCatalogImportStatuses();
    if (_disposed || !_connected) return;
    switch (result) {
      case CatalogImportStatusesSupported(:final statuses):
        final inFlight = statuses.where((status) => !_isTerminal(status)).toList(growable: false);
        if (inFlight.isEmpty || _members.isNotEmpty) return;
        _openOrJoin(
          pluginIds: [for (final status in inFlight) status.pluginId],
          observed: true,
          operationBridgeId: _activeBridgeId,
        );
        for (final status in inFlight) {
          _progressByPluginId[status.pluginId] = status;
        }
        _publishLive();
      case CatalogImportStatusesUnsupported():
        return;
      case CatalogImportStatusesFailure(:final error):
        // Nothing else logs this, and there is no retry until the next
        // reconnect, so an import already running stays invisible.
        logw("Catalog rescan could not read in-flight imports after connecting", error);
        return;
    }
  }

  bool _isTerminal(CatalogImportProgress progress) => switch (progress) {
    CatalogImportCompleted() || CatalogImportCancelled() || CatalogImportFailed() => true,
    CatalogImportEnumerating() || CatalogImportCommitting() => false,
  };

  void _publish(CatalogRescanState next) {
    if (_disposed || _state.isClosed || _state.value == next) return;
    _state.add(next);
  }
}
