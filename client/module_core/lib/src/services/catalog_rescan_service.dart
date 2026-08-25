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

/// How long a successful rescan row stays before clearing itself.
const _successVisibleFor = Duration(seconds: 4);

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
/// Naming the operation is what keeps membership, settlement, cancellation and
/// the post-run refresh consistent with one another instead of being four
/// independent rules.
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

  /// Display names for the current bridge's harnesses, so a running row can
  /// name the harness rather than echo its id.
  Map<String, String> _displayNames = const {};

  /// True when the live operation was discovered rather than started here.
  bool _observed = false;

  /// Start requests still awaiting a response, so a cancel can order itself
  /// after them rather than racing its own POST.
  final Set<Future<void>> _pendingStarts = {};

  /// A cancellation that has not finished dispatching its DELETEs.
  ///
  /// A cancel has to wait for any start still in flight, or its DELETE can
  /// overtake the POST and cancel nothing. That wait would otherwise leave a
  /// window where a new rescan could begin and inherit those DELETEs, so a
  /// start waits for the cancel to finish owning its plugin ids first.
  Future<void>? _cancelling;

  /// The harness ids a cancellation currently owns. Progress for these is not
  /// adopted: a delayed event from the run being cancelled would otherwise
  /// reopen it as an observed operation, and the next rescan would join that
  /// stale member and lose its own summary.
  final Set<String> _cancellingPluginIds = {};

  Timer? _clearTimer;
  bool _connected = _connectionService.currentStatus is ConnectionConnected;
  String? _activeBridgeId;
  bool _disposed = false;

  ValueStream<CatalogRescanState> get state => _state.stream;

  /// Fires after an observed import publishes list-visible catalog rows.
  ///
  /// List cubits use this durable-data signal rather than the progress row's
  /// lifecycle, because cancelling a row does not prove an import that already
  /// entered its atomic commit did not finish. Automatic hydration markers
  /// complete with zero published rows and do not invalidate the lists.
  Stream<void> get catalogChanged => _catalogChanged.stream;

  /// Rescans every harness this bridge can import from.
  Future<void> startAll() async {
    if (_disposed) return;
    switch (_managementService.snapshots.valueOrNull) {
      // Without a management snapshot there are no harness ids to fan out to,
      // so no request is made and no `404` would ever come back to reveal the
      // missing route. `/plugin/management` is *younger* than `/plugin/import`
      // (v1.7.0 against v1.6.0), so such a bridge may well be importing right
      // now — which is why a live operation is left alone.
      case PluginManagementLoadResultUnsupported():
        if (_members.isEmpty) _publish(const CatalogRescanState.unsupported());
      case PluginManagementLoadResultSupported(:final response):
        final pluginIds = [
          for (final plugin in response.plugins)
            if (plugin.runtimeState.isRoutable) plugin.setup.id,
        ];
        if (pluginIds.isEmpty) return;
        await _start(pluginIds: pluginIds, coversEveryHarness: true);
      case PluginManagementLoadResultLoading() || PluginManagementLoadResultFailure() || null:
        return;
    }
  }

  /// Rescans one named harness, joining the live operation when there is one.
  ///
  /// Unlike [startAll], the outcome is returned so the surface that named the
  /// harness can report a rejection instead of silently skipping it.
  Future<CatalogRescanStartResult> start({required String pluginId}) async {
    if (_disposed) return const CatalogRescanStartResult.notImportable();
    if (_managementService.snapshots.valueOrNull is PluginManagementLoadResultUnsupported) {
      // Tell the caller either way, but never overwrite a run in flight with a
      // state that reads as terminal.
      if (_members.isEmpty) _publish(const CatalogRescanState.unsupported());
      return const CatalogRescanStartResult.unsupported();
    }
    final results = await _start(pluginIds: [pluginId], coversEveryHarness: false);
    return results[pluginId] ?? const CatalogRescanStartResult.notImportable();
  }

  /// Cancels every member of the live operation, whether or not progress has
  /// begun. The route cancels one plugin per call, so this fans out.
  Future<void> cancel() {
    if (_disposed || _members.isEmpty) return Future<void>.value();
    final pluginIds = Set<String>.of(_members);
    _cancellingPluginIds.addAll(pluginIds);
    return _cancelling = _cancel(pluginIds: pluginIds);
  }

  Future<void> _cancel({required Set<String> pluginIds}) async {
    // Close first so the row goes at once, then wait for any start still in
    // flight: a DELETE that overtakes its POST finds no import to cancel, and
    // the import the user just cancelled would run anyway.
    _closeOperation(const CatalogRescanState.idle());
    try {
      await Future.wait(_pendingStarts);
      await Future.wait([
        for (final pluginId in pluginIds)
          _pluginRepository.cancelCatalogImport(pluginId: pluginId).then((outcome) {
            // A refused or unprovable cancel means that import may still be
            // running, and nothing else records it. The harness id is the only
            // thing that identifies which one, since every call shares a route.
            if (outcome
                case CatalogImportMutationFailure(:final error) || CatalogImportMutationUncertain(:final error)) {
              logw("Catalog rescan cancellation was not confirmed for $pluginId", error);
            }
          }),
      ]);
    } finally {
      _cancellingPluginIds.removeAll(pluginIds);
      _cancelling = null;
    }
  }

  /// Clears a terminal row the user has read.
  void dismiss() {
    // Membership, not the published state, decides whether a run is open: an
    // unsupported answer can be published over a live operation.
    if (_disposed || _members.isNotEmpty) return;
    _reset();
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

  Future<Map<String, CatalogRescanStartResult>> _start({
    required List<String> pluginIds,
    required bool coversEveryHarness,
  }) async {
    // Never begin inside a cancellation's window: its DELETEs are already
    // aimed at these plugin ids and would cancel this run instead. Guarded
    // rather than awaited unconditionally, because `await null` still yields,
    // and the operation must open before this call returns to its caller so an
    // immediate cancel can see it.
    if (_cancelling case final cancelling?) {
      await cancelling;
      if (_disposed) return {};
    }
    _openOrJoin(pluginIds: pluginIds, observed: false);
    final results = <String, CatalogRescanStartResult>{};
    final dispatched = [
      for (final pluginId in pluginIds)
        _pluginRepository.startCatalogImport(pluginId: pluginId).then((outcome) {
          results[pluginId] = _applyStartOutcome(pluginId: pluginId, outcome: outcome);
        }),
    ];
    _pendingStarts.addAll(dispatched);
    try {
      await Future.wait(dispatched);
    } finally {
      _pendingStarts.removeAll(dispatched);
    }
    if (_disposed) return results;
    // Two conditions, not one. `_members.isEmpty` alone is also true when the
    // operation closed while this dispatch was awaiting — settled from SSE,
    // cancelled, or reset by a disconnect — and closing it again would erase a
    // failure row that must persist and fire a second refresh. `isLive` is the
    // cheap way to tell those apart, because _openOrJoin always publishes a
    // live state before dispatch and an unsupported answer is never published
    // over a live operation.
    if (_members.isEmpty && _state.value.isLive) {
      // "No import route" is a claim about the whole bridge, so only a fan-out
      // that covered every harness may make it. A targeted start reports its
      // own rejection through the returned result instead; the bridge answers
      // 404 for an unknown *and* for a deselected plugin, so one 404 says
      // nothing about the route.
      final unsupported =
          coversEveryHarness && results.isNotEmpty && results.values.every((r) => r is CatalogRescanStartUnsupported);
      _closeOperation(
        unsupported ? const CatalogRescanState.unsupported() : const CatalogRescanState.idle(),
      );
      return results;
    }
    _publishLive();
    _settleIfComplete();
    return results;
  }

  /// Applies one dispatch outcome to membership.
  ///
  /// A harness joins on dispatch rather than on acknowledgement, so a timeout
  /// or lost response — which the relay can raise *after* the request landed —
  /// keeps it in the operation. Only an answer from the bridge removes it.
  CatalogRescanStartResult _applyStartOutcome({
    required String pluginId,
    required CatalogImportMutationResult outcome,
  }) {
    switch (outcome) {
      case CatalogImportMutationAccepted():
        return const CatalogRescanStartResult.accepted();
      case CatalogImportMutationNotFound():
        _members.remove(pluginId);
        return const CatalogRescanStartResult.unsupported();
      case CatalogImportMutationUnavailable():
        _members.remove(pluginId);
        return const CatalogRescanStartResult.notImportable();
      case CatalogImportMutationUncertain(:final error):
        // The request may well have landed, so the harness stays a member and
        // settles from its own progress event rather than being written off.
        logw("Catalog rescan start could not be confirmed for $pluginId", error);
        return CatalogRescanStartResult.failed(cause: error);
      case CatalogImportMutationFailure(:final error):
        // The bridge answered and refused, so this harness is settled and
        // counts against the run. Retained locally because the failure may
        // never have reached the bridge's own log.
        logw("Catalog rescan could not be started for $pluginId", error);
        _progressByPluginId[pluginId] = CatalogImportProgress.failed(
          pluginId: pluginId,
          message: "start rejected",
        );
        return CatalogRescanStartResult.failed(cause: error);
    }
  }

  void _openOrJoin({required List<String> pluginIds, required bool observed}) {
    if (_members.isEmpty) {
      _clearTimer?.cancel();
      _clearTimer = null;
      _progressByPluginId.clear();
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
    // An automatic hydration marker completes without catalog publication and
    // reports zero totals. Imports are non-destructive, so an actual empty
    // publication also leaves every list row unchanged. Announce a committed
    // snapshot before the operation bookkeeping below: a commit that wins a
    // user cancellation must still invalidate the lists even though the
    // progress row remains closed.
    if (progress case CatalogImportCompleted(:final projectsImported, :final sessionsImported)
        when (projectsImported > 0 || sessionsImported > 0) && !_catalogChanged.isClosed) {
      _catalogChanged.add(null);
    }

    final pluginId = progress.pluginId;
    if (!_members.contains(pluginId)) {
      // A rescan someone else started, seen live. Adopt it so its imported
      // sessions still reach the lists, but as an observed operation, which
      // claims no summary.
      if (_isTerminal(progress) || _cancellingPluginIds.contains(pluginId)) return;
      _openOrJoin(pluginIds: [pluginId], observed: true);
    }
    // Someone else cancelled a member of this run. That is intervention, not
    // failure, and it means this client no longer saw the whole operation, so
    // it settles quietly instead of publishing a persistent failure row.
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
      // Still running: re-point the row at a harness that is actually working,
      // rather than leaving it naming the one that just finished.
      if (_members.isNotEmpty) _publishLive();
      return;
    }
    _publishLive();
  }

  void _publishLive() {
    if (_members.isEmpty) return;
    final active = _activeProgress();
    _publish(
      active == null
          ? CatalogRescanState.starting(pluginIds: Set<String>.unmodifiable(_members))
          : CatalogRescanState.running(
              activePluginName: _displayNames[active.pluginId] ?? active.pluginId,
              sessionsSeen: switch (active) {
                CatalogImportEnumerating(:final sessionsSeen) => sessionsSeen,
                CatalogImportCommitting(:final sessionsSeen) => sessionsSeen,
                // Unreachable: _activeProgress only returns a non-terminal
                // status, and the switch stays exhaustive so a new phase is a
                // compile error rather than a silent zero.
                CatalogImportCompleted() || CatalogImportCancelled() || CatalogImportFailed() => 0,
              },
              pluginIds: Set<String>.unmodifiable(_members),
            ),
    );
  }

  /// The harness whose progress the row names, preferring whichever is still
  /// working over one that already settled.
  CatalogImportProgress? _activeProgress() {
    for (final pluginId in _members) {
      final progress = _progressByPluginId[pluginId];
      if (progress != null && !_isTerminal(progress)) return progress;
    }
    return null;
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
    final failedCount = settledMembers.length - succeeded.length;
    if (succeeded.isEmpty) {
      _closeOperation(CatalogRescanState.failed(harnessCount: settledMembers.length));
      return;
    }
    if (failedCount > 0) {
      _closeOperation(
        CatalogRescanState.partlyFailed(succeededCount: succeeded.length, failedCount: failedCount),
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
    _observed = false;
    _publish(next);
    if (next is CatalogRescanSucceeded) {
      _clearTimer?.cancel();
      _clearTimer = Timer(_successVisibleFor, _reset);
    }
  }

  void _reset() {
    if (_disposed) return;
    _clearTimer?.cancel();
    _clearTimer = null;
    _members.clear();
    _progressByPluginId.clear();
    _observed = false;
    _publish(const CatalogRescanState.idle());
  }

  void _onConnectionStatus(ConnectionStatus status) {
    if (_disposed) return;
    final nextConnected = status is ConnectionConnected;
    if (nextConnected == _connected) return;
    _connected = nextConnected;
    _reset();
    if (nextConnected) unawaited(_recoverInFlight());
  }

  void _onManagementSnapshot(PluginManagementLoadResult snapshot) {
    if (_disposed) return;
    if (snapshot is! PluginManagementLoadResultSupported) return;
    _displayNames = {
      for (final plugin in snapshot.response.plugins) plugin.setup.id: plugin.setup.displayName,
    };
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
