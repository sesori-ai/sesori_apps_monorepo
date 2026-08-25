import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "plugin_generation_factory.dart";

enum PluginRuntimeAccessGate() { enabled, draining, disabled }

class const PluginRuntimeAccess({
    required final String pluginId,
    required final PluginRuntimeAccessGate gate,
    required final bool startAllowed,
  });

enum PluginRuntimeState() { disabled, blocked, dormant, starting, active, degraded, stopping, failed }

enum PluginRuntimeTransition() { none, starting, stopping, restarting }

enum PluginStopIntent() { safe, force }

enum PluginRuntimeConflictReason() { inFlight, busy, workStateUnknown, transitioning, notEligible }

class const PluginRuntimeSnapshot({
    required final String pluginId,
    required final PluginProjectOwnership projectOwnership,
    required final PluginSetupStatus setup,
    required final PluginRuntimeAccessGate accessGate,
    required final bool startAllowed,
    required final int? generation,
    required final PluginRuntimeState state,
    required final PluginWorkState workState,
    required final int leaseCount,
    required final PluginRuntimeTransition transition,
  });

typedef SourcedPluginRuntimeEvent = ({
  String pluginId,
  int generation,
  BridgeSseEvent event,
  bool allowDuringStop,
  Completer<void>? terminalHandoffConsumed,
});
typedef SourcedPluginProvisionProgress = ({String pluginId, RuntimeProvisionProgress event});

class const PluginRuntimeAuthenticationOperation({required final Stream<PluginAuthenticationEvent> events, required final void Function() abort});

sealed class const PluginRuntimeCommandResult({required final PluginRuntimeSnapshot snapshot});

final class const PluginRuntimeCommandApplied({required super.snapshot}) extends PluginRuntimeCommandResult;

final class const PluginRuntimeCommandCurrent({required super.snapshot}) extends PluginRuntimeCommandResult;

final class const PluginRuntimeCommandConflict({required super.snapshot, required final List<PluginRuntimeConflictReason> reasons}) extends PluginRuntimeCommandResult;

final class const PluginRuntimeCommandFailed({required super.snapshot, required final String message}) extends PluginRuntimeCommandResult;

class PluginRuntime({
    required List<PluginRuntimeRegistration> registrations,
    required final PluginGenerationFactory _generationFactory,
    required final HostProcessService _setupProcesses,
    required Map<String, String> environment,
    required final ServerClock _clock,
    required final Duration _shutdownBudget,
  }) {
  this {
    if (_slots.length != registrations.length) {
      throw ArgumentError.value(registrations, "registrations", "must not contain duplicate plugin ids");
    }
    _snapshotsSubject = BehaviorSubject<List<PluginRuntimeSnapshot>>.seeded(_buildSnapshots());
  }

  final Map<String, String> _environment = Map<String, String>.unmodifiable(environment);
  final Map<String, _PluginRuntimeSlot> _slots = <String, _PluginRuntimeSlot>{
         for (final registration in registrations)
           registration.descriptor.id: _PluginRuntimeSlot(registration: registration),
       };
  late final BehaviorSubject<List<PluginRuntimeSnapshot>> _snapshotsSubject;
  final ReplaySubject<SourcedPluginRuntimeEvent> _backendEventsSubject = ReplaySubject<SourcedPluginRuntimeEvent>(
    maxSize: 1024,
  );
  final PublishSubject<SourcedPluginProvisionProgress> _provisionProgressSubject =
      PublishSubject<SourcedPluginProvisionProgress>();
  bool _shuttingDown = false;
  Future<void>? _shutdownStartedPluginsFuture;
  Future<void>? _disposeFuture;
  final Set<StartAbortController> _installAbortControllers = <StartAbortController>{};
  final Set<StartAbortController> _authenticationAbortControllers = <StartAbortController>{};

  Stream<List<PluginRuntimeSnapshot>> get snapshots => _snapshotsSubject.stream;
  List<PluginRuntimeSnapshot> get snapshot => _buildSnapshots();
  Stream<SourcedPluginRuntimeEvent> get backendEvents => _backendEventsSubject.stream;
  Stream<SourcedPluginProvisionProgress> get provisionProgress => _provisionProgressSubject.stream;

  Set<String> get activePluginIds => {
    for (final slot in _slots.values)
      if (_isRoutable(slot)) slot.registration.descriptor.id,
  };

  Set<String> get eligiblePluginIds => {
    for (final slot in _slots.values)
      if (slot.accessGate != PluginRuntimeAccessGate.disabled) slot.registration.descriptor.id,
  };

  Set<String> get startAllowedPluginIds => {
    for (final slot in _slots.values)
      if (slot.accessGate == PluginRuntimeAccessGate.enabled && slot.startAllowed) slot.registration.descriptor.id,
  };

  PluginDiagnostics? describe({required String pluginId}) => _requireSlot(pluginId).plugin?.describe();

  Future<Map<String, PluginSetupStatus>> inspectSetup({
    required Set<String> pluginIds,
    required bool markUnselectedNotInspected,
  }) async {
    final selectedIds = Set<String>.unmodifiable(pluginIds);
    final unknownIds = selectedIds.difference(_slots.keys.toSet());
    if (unknownIds.isNotEmpty) {
      throw ArgumentError.value(pluginIds, "pluginIds", "contains unknown plugin ids: $unknownIds");
    }
    if (markUnselectedNotInspected) {
      for (final slot in _slots.values) {
        if (!selectedIds.contains(slot.registration.descriptor.id)) {
          slot.setupInspectionRevision++;
          slot.setup = const PluginSetupNotInspected();
        }
      }
    }
    final inspections = {
      for (final pluginId in selectedIds)
        pluginId: () {
          final slot = _slots[pluginId]!;
          return (
            revision: ++slot.setupInspectionRevision,
            generation: slot.generation,
          );
        }(),
    };
    final results = await Future.wait(
      selectedIds.map((pluginId) async {
        final slot = _slots[pluginId]!;
        final descriptor = slot.registration.descriptor;
        try {
          return (
            pluginId: pluginId,
            setup: await descriptor.inspectSetup(
              config: slot.registration.config,
              processes: _setupProcesses,
              environment: _environment,
              stateDirectory: slot.registration.stateDirectory,
            ),
          );
        } on Object catch (error, stackTrace) {
          Log.w('Plugin "$pluginId" setup inspection failed', error, stackTrace);
          return (
            pluginId: pluginId,
            setup: const PluginSetupUnknown(
              actionHint: "Plugin setup could not be determined. Check the bridge console and retry.",
            ),
          );
        }
      }),
    );
    for (final result in results) {
      final slot = _slots[result.pluginId]!;
      final inspection = inspections[result.pluginId]!;
      if (slot.setupInspectionRevision == inspection.revision && slot.generation == inspection.generation) {
        slot.setup = result.setup;
      }
    }
    _publishSnapshots();
    return Map<String, PluginSetupStatus>.unmodifiable({
      for (final slot in _slots.values) slot.registration.descriptor.id: slot.setup,
    });
  }

  /// Runs the plugin descriptor's managed-runtime install and forwards its
  /// progress. Purely file-level: it never starts, stops, or mutates slot
  /// state — the caller re-inspects setup after a terminal [ProvisionReady].
  /// A shutdown aborts the install cooperatively via the returned stream's
  /// abort signal.
  Stream<RuntimeProvisionProgress> installRuntime({required String pluginId}) async* {
    final slot = _requireSlot(pluginId);
    if (_shuttingDown) {
      yield const ProvisionFailed(message: "The bridge is shutting down.");
      return;
    }
    final abortController = StartAbortController();
    _installAbortControllers.add(abortController);
    try {
      yield* slot.registration.descriptor.installRuntime(
        config: slot.registration.config,
        processes: _setupProcesses,
        environment: _environment,
        stateDirectory: slot.registration.stateDirectory,
        startAborted: abortController.signal,
      );
    } finally {
      _installAbortControllers.remove(abortController);
    }
  }

  PluginRuntimeAuthenticationOperation authenticate({required String pluginId}) {
    final slot = _requireSlot(pluginId);
    if (_shuttingDown) throw const PluginStartAbortedException();
    final descriptor = slot.registration.descriptor;
    if (descriptor is! InteractivePluginAuthenticationDescriptor) {
      throw StateError('Plugin "$pluginId" does not support interactive authentication.');
    }
    final authenticationDescriptor = descriptor as InteractivePluginAuthenticationDescriptor;
    final abortController = StartAbortController();
    _authenticationAbortControllers.add(abortController);
    final events = (() async* {
      try {
        yield* authenticationDescriptor.authenticate(
          config: slot.registration.config,
          processes: _setupProcesses,
          environment: _environment,
          stateDirectory: slot.registration.stateDirectory,
          aborted: abortController.signal,
        );
      } finally {
        _authenticationAbortControllers.remove(abortController);
      }
    })();
    return PluginRuntimeAuthenticationOperation(events: events, abort: abortController.abort);
  }

  void applyAccess({required List<PluginRuntimeAccess> entries}) {
    final byId = <String, PluginRuntimeAccess>{for (final entry in entries) entry.pluginId: entry};
    if (byId.length != entries.length || byId.keys.toSet().difference(_slots.keys.toSet()).isNotEmpty) {
      throw ArgumentError.value(entries, "entries", "must contain unique registered plugin ids");
    }
    for (final slot in _slots.values) {
      final entry = byId[slot.registration.descriptor.id];
      if (slot.accessGate == PluginRuntimeAccessGate.draining) continue;
      slot
        ..accessGate = entry?.gate ?? PluginRuntimeAccessGate.disabled
        ..startAllowed = (entry?.startAllowed ?? false) && slot.setup is! PluginSetupAuthenticationRequired;
    }
    _publishSnapshots();
  }

  Future<void> startEager({required List<String> pluginIds}) async {
    await Future.wait([for (final pluginId in pluginIds) _ensureStarted(slot: _requireSlot(pluginId))]);
  }

  Future<T> use<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async => (await useWithGeneration(pluginId: pluginId, operation: operation, body: body)).value;

  Future<({T value, int generation})> useWithGeneration<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) async {
    final lease = await _acquire(pluginId: pluginId, operation: operation, startIfNeeded: true);
    try {
      final result = await body(lease.api);
      _requireCurrentGeneration(lease: lease, operation: operation);
      return (value: result, generation: lease.generation);
    } on PluginAuthenticationRequiredException catch (error) {
      _handleAuthenticationRequired(lease: lease, failure: error);
      rethrow;
    } finally {
      _release(lease);
    }
  }

  /// Runs interruptible plugin work, then linearizes a short durable commit
  /// before this generation can be replaced. Force-stop remains able to
  /// interrupt [prepare], but waits for an entered [commit] to finish. The
  /// commit receives the protected generation so durable follow-up events can
  /// retain generation fencing after the lease is released.
  Future<R> useAndCommit<P, R>({
    required String pluginId,
    required Enum operation,
    required Future<P> Function(BridgePluginApi api) prepare,
    required Future<R> Function(P prepared, int generation) commit,
  }) async {
    final lease = await _acquire(pluginId: pluginId, operation: operation, startIfNeeded: true);
    var commitProtected = false;
    try {
      final prepared = await prepare(lease.api);
      _beginDurableCommit(lease: lease, operation: operation);
      commitProtected = true;
      final result = await commit(prepared, lease.generation);
      _requireSameGeneration(lease: lease, operation: operation);
      return result;
    } on PluginAuthenticationRequiredException catch (error) {
      _handleAuthenticationRequired(lease: lease, failure: error);
      rethrow;
    } finally {
      if (commitProtected) _endDurableCommit(lease.slot);
      _release(lease);
    }
  }

  /// Runs a short durable commit only while [generation] is current and keeps
  /// replacement from crossing the commit boundary once it has been entered.
  Future<R> commitCurrentGeneration<R>({
    required String pluginId,
    required int generation,
    required Enum operation,
    required Future<R> Function() commit,
  }) async {
    if (_shuttingDown) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "bridge is shutting down");
    }
    final slot = _requireOperationSlot(pluginId: pluginId, operation: operation);
    final plugin = slot.plugin;
    if (plugin == null || slot.generation != generation || !_isRoutable(slot)) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin generation changed before durable commit",
      );
    }
    final lease = _PluginLease(slot: slot, generation: generation, api: plugin.api);
    slot.leaseCount++;
    var commitProtected = false;
    try {
      _beginDurableCommit(lease: lease, operation: operation);
      commitProtected = true;
      _publishSnapshots();
      final result = await commit();
      _requireSameGeneration(lease: lease, operation: operation);
      return result;
    } finally {
      if (commitProtected) _endDurableCommit(slot);
      _release(lease);
    }
  }

  Stream<T> useStream<T>({
    required String pluginId,
    required Enum operation,
    required Stream<T> Function(BridgePluginApi api, int generation) body,
  }) {
    StreamSubscription<T>? sourceSubscription;
    _PluginLease? lease;
    Future<void>? termination;
    Future<void> Function()? generationCancellation;
    var cancelled = false;
    var released = false;

    void releaseLease() {
      if (released) return;
      final activeLease = lease;
      if (activeLease == null) return;
      released = true;
      _release(activeLease);
    }

    late final StreamController<T> controller;

    Future<void> finish({
      Object? error,
      StackTrace? stackTrace,
      required bool cancelSource,
      bool surfaceCancellationError = false,
    }) {
      return termination ??= () async {
        if (error is PluginAuthenticationRequiredException) {
          final activeLease = lease;
          if (activeLease != null) _handleAuthenticationRequired(lease: activeLease, failure: error);
        }
        if (error != null && !cancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
        // A synchronous source can invoke its callback before listen() returns
        // the subscription. Yield once so the retained subscription is visible
        // before terminal cancellation reads it.
        await Future<void>.value();
        try {
          if (cancelSource) await sourceSubscription?.cancel();
        } on Object catch (cancelError, cancelStackTrace) {
          if (surfaceCancellationError) rethrow;
          if (error == null && !cancelled && !controller.isClosed) {
            controller.addError(cancelError, cancelStackTrace);
          } else {
            Log.w(
              'Plugin "$pluginId" stream cancellation failed during ${operation.name}',
              cancelError,
              cancelStackTrace,
            );
          }
        } finally {
          final activeLease = lease;
          final cancellation = generationCancellation;
          if (activeLease != null && cancellation != null) {
            activeLease.slot.operationStreamCancellations.remove(cancellation);
          }
          generationCancellation = null;
          releaseLease();
          if (!cancelled && !controller.isClosed) unawaited(controller.close());
        }
      }();
    }

    controller = StreamController<T>(
      onListen: () async {
        try {
          final acquired = await _acquire(pluginId: pluginId, operation: operation, startIfNeeded: true);
          lease = acquired;
          if (cancelled) {
            releaseLease();
            return;
          }
          generationCancellation = () => finish(cancelSource: true);
          acquired.slot.operationStreamCancellations.add(generationCancellation!);
          sourceSubscription = body(acquired.api, acquired.generation).listen(
            (value) {
              try {
                _requireCurrentGeneration(lease: acquired, operation: operation);
                controller.add(value);
              } on Object catch (error, stackTrace) {
                unawaited(finish(error: error, stackTrace: stackTrace, cancelSource: true));
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              unawaited(finish(error: error, stackTrace: stackTrace, cancelSource: true));
            },
            onDone: () {
              try {
                _requireCurrentGeneration(lease: acquired, operation: operation);
                unawaited(finish(cancelSource: false));
              } on Object catch (error, stackTrace) {
                unawaited(finish(error: error, stackTrace: stackTrace, cancelSource: false));
              }
            },
          );
          if (cancelled) await finish(cancelSource: true);
        } on Object catch (error, stackTrace) {
          await finish(error: error, stackTrace: stackTrace, cancelSource: true);
        }
      },
      onPause: () => sourceSubscription?.pause(),
      onResume: () => sourceSubscription?.resume(),
      onCancel: () async {
        cancelled = true;
        if (termination != null) return;
        await finish(cancelSource: true, surfaceCancellationError: true);
      },
    );
    return controller.stream;
  }

  Future<T?> useIfActive<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api, int generation) body,
  }) async {
    final slot = _requireOperationSlot(pluginId: pluginId, operation: operation);
    if (!_isRoutable(slot)) return null;
    final lease = await _acquire(pluginId: pluginId, operation: operation, startIfNeeded: false);
    try {
      final result = await body(lease.api, lease.generation);
      _requireCurrentGeneration(lease: lease, operation: operation);
      return result;
    } on PluginAuthenticationRequiredException catch (error) {
      _handleAuthenticationRequired(lease: lease, failure: error);
      rethrow;
    } finally {
      _release(lease);
    }
  }

  bool isCurrentGeneration({required String pluginId, required int generation}) {
    final slot = _slots[pluginId];
    return slot != null && slot.generation == generation && _isRoutable(slot);
  }

  /// Runtime-authorized stop events stay valid while their generation exists.
  /// A successor generation fences any older event still queued for delivery.
  bool isCurrentEventGeneration({required String pluginId, required int generation}) {
    final slot = _slots[pluginId];
    return slot != null && slot.generation == generation;
  }

  bool isCurrentEvent({
    required String pluginId,
    required int generation,
    required bool allowDuringStop,
  }) {
    return isCurrentGeneration(pluginId: pluginId, generation: generation) ||
        (allowDuringStop && isCurrentEventGeneration(pluginId: pluginId, generation: generation));
  }

  void requireCurrentGeneration({
    required String pluginId,
    required int generation,
    required Enum operation,
  }) {
    if (!isCurrentGeneration(pluginId: pluginId, generation: generation)) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin generation changed during operation",
      );
    }
  }

  Future<PluginRuntimeCommandResult> start({required String pluginId}) async {
    final slot = _requireSlot(pluginId);
    if (slot.accessGate == PluginRuntimeAccessGate.disabled) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.notEligible],
      );
    }
    if (slot.accessGate == PluginRuntimeAccessGate.draining) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    if (_isRoutable(slot)) return PluginRuntimeCommandCurrent(snapshot: _snapshotFor(slot));
    if (slot.transition != PluginRuntimeTransition.none && slot.transition != PluginRuntimeTransition.starting) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    final plugin = await _ensureStarted(slot: slot);
    if (plugin == null || !_isRoutable(slot)) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: "plugin failed to start");
    }
    return PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot));
  }

  Future<PluginRuntimeCommandResult> stop({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    final slot = _requireSlot(pluginId);
    if (_stopPreconditionConflict(slot: slot, intent: intent) case final conflict?) return conflict;
    final hadPlugin = slot.plugin != null || slot.startFuture != null;
    if (!hadPlugin) return PluginRuntimeCommandCurrent(snapshot: _snapshotFor(slot));

    final generationLabel = slot.generation?.toString() ?? "pending";
    Log.d('Stopping plugin "$pluginId" generation $generationLabel (${intent.name})');
    final commandTransition = _beginCommandTransition(
      slot: slot,
      transition: PluginRuntimeTransition.stopping,
    );
    String? failureMessage;
    try {
      await _stopCurrentGeneration(slot: slot, intent: intent);
      if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.dormant;
    } on Object catch (error) {
      if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.failed;
      failureMessage = "$error";
    } finally {
      _settleCommandTransition(slot: slot, commandTransition: commandTransition);
    }
    if (failureMessage != null) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: failureMessage);
    }
    Log.d('Plugin "$pluginId" generation $generationLabel stopped');
    return PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot));
  }

  Future<PluginRuntimeCommandResult> prepareDisable({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    final slot = _requireSlot(pluginId);
    if (_stopPreconditionConflict(slot: slot, intent: intent) case final conflict?) return conflict;
    final hadPlugin = slot.plugin != null || slot.startFuture != null;
    slot.accessGate = PluginRuntimeAccessGate.draining;
    slot.setupInspectionRevision++;
    _publishSnapshots();

    final commandTransition = _beginCommandTransition(
      slot: slot,
      transition: PluginRuntimeTransition.stopping,
    );
    if (!hadPlugin) return PluginRuntimeCommandCurrent(snapshot: _snapshotFor(slot));

    final generationLabel = slot.generation?.toString() ?? "pending";
    Log.d('Preparing plugin "$pluginId" generation $generationLabel for disable (${intent.name})');
    try {
      await _stopCurrentGeneration(slot: slot, intent: intent);
      if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        throw StateError('Plugin "$pluginId" disable preparation lost transition ownership.');
      }
      slot.state = PluginRuntimeState.dormant;
      _publishSnapshots();
      return PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot));
    } on Object catch (error) {
      if (_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        slot
          ..state = PluginRuntimeState.failed
          ..accessGate = PluginRuntimeAccessGate.enabled;
        _settleCommandTransition(slot: slot, commandTransition: commandTransition);
      }
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: "$error");
    }
  }

  void commitDisable({required String pluginId}) {
    final slot = _requireSlot(pluginId);
    final wasPrepared = _isPreparedDisableSlot(slot);
    slot
      ..accessGate = PluginRuntimeAccessGate.disabled
      ..startAllowed = false
      ..state = PluginRuntimeState.dormant;
    _settlePreparedDisable(slot);
    if (!wasPrepared) {
      throw StateError('Plugin "$pluginId" did not have a valid prepared disable; settled disabled.');
    }
  }

  void rollbackDisable({required String pluginId}) {
    final slot = _requireSlot(pluginId);
    final wasPrepared = _isPreparedDisableSlot(slot);
    slot
      ..accessGate = PluginRuntimeAccessGate.enabled
      ..state = PluginRuntimeState.dormant;
    _settlePreparedDisable(slot);
    if (!wasPrepared) {
      throw StateError('Plugin "$pluginId" did not have a valid prepared disable; settled enabled.');
    }
  }

  Future<PluginRuntimeCommandResult> restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    final slot = _requireSlot(pluginId);
    if (!_shuttingDown && slot.accessGate == PluginRuntimeAccessGate.enabled && !slot.startAllowed) {
      return PluginRuntimeCommandFailed(
        snapshot: _snapshotFor(slot),
        message: "plugin $pluginId is unavailable",
      );
    }
    if (_stopPreconditionConflict(slot: slot, intent: intent) case final conflict?) return conflict;

    final commandTransition = _beginCommandTransition(
      slot: slot,
      transition: PluginRuntimeTransition.restarting,
    );
    String? failureMessage;
    try {
      await _stopCurrentGeneration(slot: slot, intent: intent);
      if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.dormant;
      if (_shuttingDown) {
        failureMessage = "bridge is shutting down";
      } else {
        final plugin = await _beginStart(
          slot: slot,
          transition: PluginRuntimeTransition.restarting,
          clearTransitionOnSettle: false,
        );
        if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
          return PluginRuntimeCommandConflict(
            snapshot: _snapshotFor(slot),
            reasons: const [PluginRuntimeConflictReason.transitioning],
          );
        }
        if (plugin == null || !_hasOperationalGeneration(slot)) failureMessage = "plugin failed to restart";
      }
    } on Object catch (error) {
      if (!_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.failed;
      failureMessage = "$error";
    } finally {
      _settleCommandTransition(slot: slot, commandTransition: commandTransition);
    }
    if (failureMessage != null) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: failureMessage);
    }
    return PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot));
  }

  PluginRuntimeCommandResult? _stopPreconditionConflict({
    required _PluginRuntimeSlot slot,
    required PluginStopIntent intent,
  }) {
    if (_shuttingDown) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: "bridge is shutting down");
    }
    if (slot.accessGate == PluginRuntimeAccessGate.disabled) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.notEligible],
      );
    }
    if (slot.accessGate == PluginRuntimeAccessGate.draining) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    final forceCanTakeOverTransition =
        intent == PluginStopIntent.force &&
        slot.commandTransition == null &&
        slot.cleanupFuture == null &&
        (slot.transition == PluginRuntimeTransition.starting ||
            (slot.transition == PluginRuntimeTransition.stopping && slot.plugin != null));
    if (slot.commandTransition != null ||
        (slot.transition != PluginRuntimeTransition.none && !forceCanTakeOverTransition)) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    final hadPlugin = slot.plugin != null || slot.startFuture != null;
    final hasLiveGeneration = slot.plugin != null;
    if (intent == PluginStopIntent.safe && hadPlugin && slot.leaseCount > 0) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.inFlight],
      );
    }
    if (intent == PluginStopIntent.safe && hasLiveGeneration && slot.workState == PluginWorkState.busy) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.busy],
      );
    }
    if (intent == PluginStopIntent.safe && hasLiveGeneration && slot.workState == PluginWorkState.unknown) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.workStateUnknown],
      );
    }
    return null;
  }

  _CommandTransition _beginCommandTransition({
    required _PluginRuntimeSlot slot,
    required PluginRuntimeTransition transition,
  }) {
    final commandTransition = (owner: Object(), completer: Completer<void>());
    slot
      ..commandTransition = commandTransition
      ..transition = transition;
    _publishSnapshots();
    return commandTransition;
  }

  bool _ownsCommandTransition({
    required _PluginRuntimeSlot slot,
    required _CommandTransition commandTransition,
  }) => identical(slot.commandTransition?.owner, commandTransition.owner);

  void _settleCommandTransition({
    required _PluginRuntimeSlot slot,
    required _CommandTransition commandTransition,
  }) {
    if (_ownsCommandTransition(slot: slot, commandTransition: commandTransition)) {
      slot
        ..commandTransition = null
        ..transition = PluginRuntimeTransition.none;
    }
    _publishSnapshots();
    if (!commandTransition.completer.isCompleted) commandTransition.completer.complete();
  }

  void beginShutdown() {
    if (_shuttingDown) return;
    _shuttingDown = true;
    for (final controller in _installAbortControllers) {
      controller.abort();
    }
    for (final controller in _authenticationAbortControllers) {
      controller.abort();
    }
    for (final slot in _slots.values) {
      slot.startAbortController?.abort();
      final leaseDrainCompleter = slot.leaseDrainCompleter;
      slot.leaseDrainCompleter = null;
      if (leaseDrainCompleter != null && !leaseDrainCompleter.isCompleted) {
        leaseDrainCompleter.complete();
      }
    }
  }

  /// Best-effort, budgeted cancellation of in-flight agent work across every
  /// started plugin. Invoked by the composition root's shutdown coordinator
  /// as a signal-phase action — after [beginShutdown] has fenced new lease
  /// acquisitions, and awaited before the drain phase — so session-teardown
  /// drains (relay completions, session operations, plugin-event tails) are
  /// not held open by agent-coupled requests — an ACP `session/prompt`
  /// awaiting a busy agent, a `session/load`/`session/resume` replay, or a
  /// lazy agent respawn — while the agent process is still alive and can
  /// answer a cancellation.
  ///
  /// Unlike the forced-stop path ([_interruptActiveWork]) there is no barrier
  /// drain of pre-fence operations first (interrupting them is the point) and
  /// no terminal handoff afterwards; cancellation events the plugins emit
  /// reach the concurrently tearing-down session only on a best-effort basis.
  /// Never throws; isolates and logs per-plugin failures.
  Future<void> interruptActiveWorkForShutdown() {
    return Future.wait([
      for (final slot in _slots.values)
        if (slot.plugin case final plugin?) _interruptPluginForShutdown(slot: slot, plugin: plugin),
    ]);
  }

  Future<void> _interruptPluginForShutdown({
    required _PluginRuntimeSlot slot,
    required BridgePlugin plugin,
  }) async {
    try {
      await plugin.interruptActiveWork(budget: _shutdownBudget).timeout(_shutdownBudget);
    } on Object catch (error, stackTrace) {
      Log.w(
        'Plugin "${slot.registration.descriptor.id}" could not interrupt active work during shutdown',
        error,
        stackTrace,
      );
    }
  }

  Future<void> shutdownStartedPlugins() => _shutdownStartedPluginsFuture ??= _shutdownStartedPlugins();

  Future<void> _shutdownStartedPlugins() async {
    final errors = <({Object error, StackTrace stackTrace})>[];
    final shutdowns = Map<BridgePlugin, Future<void>>.identity();

    Future<void> capture(Future<void> operation) async {
      try {
        await operation;
      } on PluginStartAbortedException {
        // Expected when beginShutdown aborts an in-flight generation start.
      } on Object catch (error, stackTrace) {
        errors.add((error: error, stackTrace: stackTrace));
      }
    }

    Future<void> shutdown(BridgePlugin plugin) {
      if (shutdowns.containsKey(plugin)) {
        return Future<void>.value();
      }
      final operation = Future<void>.sync(() => plugin.shutdown(budget: _shutdownBudget));
      shutdowns[plugin] = operation;
      return capture(operation);
    }

    final starts = [for (final slot in _slots.values) ?slot.startFuture];
    await Future.wait([
      for (final slot in _slots.values)
        if (slot.plugin case final plugin?) shutdown(plugin),
      for (final start in starts) capture(start.then<void>((_) {})),
    ]);
    await Future.wait([
      for (final slot in _slots.values)
        if (slot.plugin case final plugin?) shutdown(plugin),
    ]);
    if (errors case [final first, ...]) {
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    beginShutdown();
    final errors = <({Object error, StackTrace stackTrace})>[];
    await Future.wait([
      for (final slot in _slots.values)
        () async {
          try {
            await slot.startFuture;
          } on PluginStartAbortedException {
            // Expected after beginShutdown aborts an in-flight generation start.
          } on Object catch (error, stackTrace) {
            errors.add((error: error, stackTrace: stackTrace));
          }
          try {
            await slot.cleanupFuture;
            await slot.commandTransition?.completer.future;
            await _waitForDurableCommits(slot);
            await _cancelAndShutdownGeneration(slot: slot, plugin: slot.plugin);
          } on Object catch (error, stackTrace) {
            errors.add((error: error, stackTrace: stackTrace));
          }
        }(),
    ]);
    await _backendEventsSubject.close();
    await _provisionProgressSubject.close();
    await _snapshotsSubject.close();
    if (errors case [final first, ...]) {
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  bool _isPreparedDisableSlot(_PluginRuntimeSlot slot) {
    return slot.accessGate == PluginRuntimeAccessGate.draining &&
        slot.commandTransition != null &&
        slot.transition == PluginRuntimeTransition.stopping &&
        slot.plugin == null &&
        slot.startFuture == null;
  }

  void _settlePreparedDisable(_PluginRuntimeSlot slot) {
    final commandTransition = slot.commandTransition;
    slot
      ..commandTransition = null
      ..transition = PluginRuntimeTransition.none;
    try {
      _publishSnapshots();
    } finally {
      if (commandTransition != null && !commandTransition.completer.isCompleted) {
        commandTransition.completer.complete();
      }
    }
  }

  Future<void> _stopCurrentGeneration({
    required _PluginRuntimeSlot slot,
    required PluginStopIntent intent,
  }) async {
    if (intent == PluginStopIntent.force) slot.startAbortController?.abort();
    Object? startError;
    StackTrace? startStackTrace;
    try {
      await slot.startFuture;
    } on PluginStartAbortedException catch (error, stackTrace) {
      if (intent != PluginStopIntent.force && !_shuttingDown) {
        startError = error;
        startStackTrace = stackTrace;
      }
    } on Object catch (error, stackTrace) {
      startError = error;
      startStackTrace = stackTrace;
    }
    await slot.cleanupFuture;
    final plugin = slot.plugin;
    if (intent == PluginStopIntent.force && plugin != null) {
      final budgetElapsed = Stopwatch()..start();
      final activeSessionIds = _snapshotActiveSessionIds(slot: slot, plugin: plugin);
      final barrierDrained = await _drainForcedStopBarrier(
        slot: slot,
        budgetElapsed: budgetElapsed,
      );
      if (barrierDrained) {
        if (plugin.currentWorkState == PluginWorkState.idle) {
          await _emitTerminalHandoff(
            slot: slot,
            sessionIds: activeSessionIds,
            emitProjectSentinel: activeSessionIds.isNotEmpty,
            budgetElapsed: budgetElapsed,
          );
        } else {
          await _interruptActiveWork(
            slot: slot,
            plugin: plugin,
            activeSessionIds: activeSessionIds,
            budgetElapsed: budgetElapsed,
          );
        }
      }
    } else {
      await _waitForDurableCommits(slot);
    }
    slot
      ..plugin = null
      ..state = PluginRuntimeState.stopping
      ..workState = PluginWorkState.unknown;
    _publishSnapshots();
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await _cancelAndShutdownGeneration(slot: slot, plugin: plugin);
    } on Object catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }
    if (startError != null) Error.throwWithStackTrace(startError, startStackTrace!);
    if (cleanupError != null) Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
  }

  Set<String> _snapshotActiveSessionIds({
    required _PluginRuntimeSlot slot,
    required BridgePlugin plugin,
  }) {
    try {
      return {
        for (final summary in plugin.api.getActiveSessionsSummary())
          for (final session in summary.activeSessions) ...[
            session.id,
            ...session.childSessionIds,
          ],
      };
    } on Object catch (error, stackTrace) {
      Log.w(
        'Plugin "${slot.registration.descriptor.id}" active-session snapshot failed before forced stop',
        error,
        stackTrace,
      );
      return const {};
    }
  }

  Future<void> _interruptActiveWork({
    required _PluginRuntimeSlot slot,
    required BridgePlugin plugin,
    required Set<String> activeSessionIds,
    required Stopwatch budgetElapsed,
  }) async {
    final pluginId = slot.registration.descriptor.id;
    final Set<String> interruptedSessionIds;
    slot.allowPendingInputResolutionsDuringStop = true;
    try {
      final remaining = _remainingShutdownBudget(budgetElapsed: budgetElapsed);
      interruptedSessionIds = await plugin.interruptActiveWork(budget: remaining).timeout(remaining);
      // Plugin event streams are asynchronous. Let cancellation resolutions
      // already emitted by the completed interruption reach the runtime before
      // the final handoff sentinel is enqueued.
      await Future<void>.delayed(Duration.zero);
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" could not quiesce active work before forced stop', error, stackTrace);
      return;
    } finally {
      slot.allowPendingInputResolutionsDuringStop = false;
    }
    await _emitTerminalHandoff(
      slot: slot,
      sessionIds: {...activeSessionIds, ...interruptedSessionIds},
      emitProjectSentinel: true,
      budgetElapsed: budgetElapsed,
    );
  }

  Future<void> _emitTerminalHandoff({
    required _PluginRuntimeSlot slot,
    required Set<String> sessionIds,
    required bool emitProjectSentinel,
    required Stopwatch budgetElapsed,
  }) async {
    final pluginId = slot.registration.descriptor.id;
    final generation = slot.generation;
    if (generation == null || _backendEventsSubject.isClosed) return;
    for (final sessionId in sessionIds.toList()..sort()) {
      _backendEventsSubject.add((
        pluginId: pluginId,
        generation: generation,
        event: BridgeSseTerminalHandoff(
          event: BridgeSseSessionIdle(sessionID: sessionId),
        ),
        allowDuringStop: true,
        terminalHandoffConsumed: null,
      ));
    }
    if (emitProjectSentinel) {
      final consumed = Completer<void>();
      _backendEventsSubject.add((
        pluginId: pluginId,
        generation: generation,
        event: const BridgeSseTerminalHandoff(
          event: BridgeSseProjectUpdated(),
        ),
        allowDuringStop: true,
        terminalHandoffConsumed: consumed,
      ));
      try {
        await consumed.future.timeout(_remainingShutdownBudget(budgetElapsed: budgetElapsed));
      } on Object catch (error, stackTrace) {
        Log.w('Plugin "$pluginId" terminal handoff was not consumed before forced stop', error, stackTrace);
      }
    }
  }

  Future<bool> _drainForcedStopBarrier({
    required _PluginRuntimeSlot slot,
    required Stopwatch budgetElapsed,
  }) async {
    final pluginId = slot.registration.descriptor.id;
    try {
      await _cancelOperationStreams(slot).timeout(_remainingShutdownBudget(budgetElapsed: budgetElapsed));
      await _waitForLeaseDrain(slot).timeout(_remainingShutdownBudget(budgetElapsed: budgetElapsed));
      await _waitForDurableCommits(slot).timeout(_remainingShutdownBudget(budgetElapsed: budgetElapsed));
      return true;
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" still had in-flight operations at forced stop', error, stackTrace);
      return false;
    }
  }

  Duration _remainingShutdownBudget({required Stopwatch budgetElapsed}) {
    final remaining = _shutdownBudget - budgetElapsed.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Plugin forced-stop budget elapsed");
    }
    return remaining;
  }

  Future<_PluginLease> _acquire({
    required String pluginId,
    required Enum operation,
    required bool startIfNeeded,
  }) async {
    if (_shuttingDown) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "bridge is shutting down");
    }
    final slot = _requireOperationSlot(pluginId: pluginId, operation: operation);
    if (slot.accessGate != PluginRuntimeAccessGate.enabled || !slot.startAllowed) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is unavailable");
    }
    if (_blocksAcquisition(slot)) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is transitioning");
    }
    if (!_isRoutable(slot) && startIfNeeded) await _ensureStarted(slot: slot);
    if (_blocksAcquisition(slot)) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is transitioning");
    }
    final plugin = slot.plugin;
    final generation = slot.generation;
    if (plugin == null || generation == null || !_isRoutable(slot)) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "plugin $pluginId is not running");
    }
    slot.leaseCount++;
    _publishSnapshots();
    return _PluginLease(slot: slot, generation: generation, api: plugin.api);
  }

  void _release(_PluginLease lease) {
    if (lease.slot.leaseCount > 0) lease.slot.leaseCount--;
    if (lease.slot.leaseCount == 0) {
      final leaseDrainCompleter = lease.slot.leaseDrainCompleter;
      lease.slot.leaseDrainCompleter = null;
      if (leaseDrainCompleter != null && !leaseDrainCompleter.isCompleted) {
        leaseDrainCompleter.complete();
      }
    }
    _publishSnapshots();
  }

  void _beginDurableCommit({required _PluginLease lease, required Enum operation}) {
    _requireCurrentGeneration(lease: lease, operation: operation);
    lease.slot.durableCommitCount++;
  }

  void _endDurableCommit(_PluginRuntimeSlot slot) {
    if (slot.durableCommitCount > 0) slot.durableCommitCount--;
    if (slot.durableCommitCount != 0) return;
    slot.durableCommitsDrained?.complete();
    slot.durableCommitsDrained = null;
  }

  Future<void> _waitForDurableCommits(_PluginRuntimeSlot slot) {
    if (slot.durableCommitCount == 0) return Future<void>.value();
    return (slot.durableCommitsDrained ??= Completer<void>()).future;
  }

  Future<void> _waitForLeaseDrain(_PluginRuntimeSlot slot) {
    if (_shuttingDown || slot.leaseCount == 0) return Future<void>.value();
    return (slot.leaseDrainCompleter ??= Completer<void>()).future;
  }

  void _requireCurrentGeneration({required _PluginLease lease, required Enum operation}) {
    requireCurrentGeneration(
      pluginId: lease.slot.registration.descriptor.id,
      generation: lease.generation,
      operation: operation,
    );
    if (!identical(lease.slot.plugin?.api, lease.api)) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin generation changed during operation",
      );
    }
  }

  void _requireSameGeneration({required _PluginLease lease, required Enum operation}) {
    if (lease.slot.generation != lease.generation || !identical(lease.slot.plugin?.api, lease.api)) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin generation changed during operation",
      );
    }
  }

  Future<BridgePlugin?> _ensureStarted({required _PluginRuntimeSlot slot}) {
    if (_isRoutable(slot)) return Future<BridgePlugin?>.value(slot.plugin);
    final existing = slot.startFuture;
    if (existing != null) return existing;
    if (_shuttingDown ||
        slot.accessGate != PluginRuntimeAccessGate.enabled ||
        !slot.startAllowed ||
        slot.transition != PluginRuntimeTransition.none) {
      return Future<BridgePlugin?>.value();
    }
    return _beginStart(
      slot: slot,
      transition: PluginRuntimeTransition.starting,
      clearTransitionOnSettle: true,
    );
  }

  Future<BridgePlugin?> _beginStart({
    required _PluginRuntimeSlot slot,
    required PluginRuntimeTransition transition,
    required bool clearTransitionOnSettle,
  }) {
    final pluginId = slot.registration.descriptor.id;
    final generation = (slot.generation ?? 0) + 1;
    Log.d('Starting plugin "$pluginId" generation $generation at ${_clock.now().toIso8601String()}');
    final abortController = StartAbortController();
    slot
      ..generation = generation
      ..transition = transition
      ..state = PluginRuntimeState.starting
      ..workState = PluginWorkState.unknown
      ..startAbortController = abortController;
    _publishSnapshots();

    late final Future<BridgePlugin?> tracked;
    tracked =
        _startGeneration(
          slot: slot,
          generation: generation,
          abortController: abortController,
        ).whenComplete(() {
          if (identical(slot.startFuture, tracked)) slot.startFuture = null;
          if (identical(slot.startAbortController, abortController)) slot.startAbortController = null;
          if (clearTransitionOnSettle && slot.transition == transition) {
            slot.transition = PluginRuntimeTransition.none;
          }
          _publishSnapshots();
        });
    slot.startFuture = tracked;
    return tracked;
  }

  Future<BridgePlugin?> _startGeneration({
    required _PluginRuntimeSlot slot,
    required int generation,
    required StartAbortController abortController,
  }) async {
    final pluginId = slot.registration.descriptor.id;
    BridgePlugin? started;
    try {
      await for (final event in _generationFactory.start(
        registration: slot.registration,
        startAborted: abortController.signal,
      )) {
        switch (event) {
          case PluginGenerationProvisionProgress(:final event):
            _provisionProgressSubject.add((pluginId: pluginId, event: event));
          case PluginGenerationStarted(:final plugin):
            started = plugin;
        }
      }
      if (started == null) {
        throw PluginGenerationStartFailedException(
          pluginId: pluginId,
          cause: StateError('Plugin "$pluginId" start produced no terminal plugin.'),
        );
      }
      if (_shuttingDown || abortController.isAborted) {
        await started.shutdown(budget: _shutdownBudget);
        throw const PluginStartAbortedException();
      }
      _validateStartedPlugin(slot: slot, plugin: started);
      slot.plugin = started;
      final startedApi = started.api;
      slot.statusSubscription = started.status.listen(
        (status) => _applyStatus(slot: slot, generation: generation, status: status),
        onError: (Object error, StackTrace stackTrace) {
          if (slot.generation != generation) return;
          if (_shuttingDown) return;
          Log.w('Plugin "$pluginId" status stream failed', error, stackTrace);
          _retireFailedGeneration(slot: slot, generation: generation, reason: "status stream failed");
        },
        onDone: () {
          if (slot.generation != generation || slot.plugin == null) return;
          if (_shuttingDown) return;
          Log.w('Plugin "$pluginId" status stream closed before the generation stopped');
          _retireFailedGeneration(slot: slot, generation: generation, reason: "status stream closed");
        },
      );
      slot.workState = started.currentWorkState;
      slot.workSubscription = started.workState.listen(
        (workState) {
          if (slot.generation != generation) return;
          slot.workState = workState;
          _publishSnapshots();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (slot.generation != generation) return;
          Log.w('Plugin "$pluginId" work-state stream failed; treating work state as unknown', error, stackTrace);
          slot.workState = PluginWorkState.unknown;
          _publishSnapshots();
        },
        onDone: () {
          if (slot.generation != generation || slot.plugin == null) return;
          slot.workState = PluginWorkState.unknown;
          _publishSnapshots();
        },
      );
      slot.eventSubscription = started.api.events.listen(
        (event) {
          if (slot.generation == generation && !_backendEventsSubject.isClosed) {
            _backendEventsSubject.add((
              pluginId: pluginId,
              generation: generation,
              event: event,
              allowDuringStop: slot.allowPendingInputResolutionsDuringStop && _isPendingInputResolution(event),
              terminalHandoffConsumed: null,
            ));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_shuttingDown) return;
          if (error is PluginAuthenticationRequiredException) {
            _handleGenerationAuthenticationRequired(
              slot: slot,
              generation: generation,
              api: startedApi,
              failure: error,
            );
            return;
          }
          if (slot.generation == generation && !_backendEventsSubject.isClosed) {
            _backendEventsSubject.addError(error, stackTrace);
          }
          if (slot.generation == generation) {
            Log.w('Plugin "$pluginId" event stream failed', error, stackTrace);
            _retireFailedGeneration(slot: slot, generation: generation, reason: "event stream failed");
          }
        },
        onDone: () {
          if (slot.generation != generation || slot.plugin == null) return;
          if (_shuttingDown) return;
          Log.w('Plugin "$pluginId" event stream closed before the generation stopped');
          _retireFailedGeneration(slot: slot, generation: generation, reason: "event stream closed");
        },
      );
      _applyStatus(slot: slot, generation: generation, status: started.currentStatus);
      Log.d('Plugin "$pluginId" generation $generation started (${slot.state.name})');
      return started;
    } on PluginStartAbortedException {
      slot.state = PluginRuntimeState.failed;
      if (started != null && !identical(slot.plugin, started)) {
        await _shutdownFailedStart(pluginId: pluginId, plugin: started);
      }
      rethrow;
    } on PluginGenerationStartFailedException catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" failed to start', error, stackTrace);
      slot.state = PluginRuntimeState.failed;
      if (started != null) await _discardStartedPlugin(slot: slot, pluginId: pluginId, plugin: started);
      return null;
    } on Object catch (error, stackTrace) {
      slot.state = PluginRuntimeState.failed;
      if (started == null) rethrow;
      if (_shuttingDown || abortController.isAborted) {
        await _discardStartedPlugin(slot: slot, pluginId: pluginId, plugin: started);
        Error.throwWithStackTrace(error, stackTrace);
      }
      Log.w('Plugin "$pluginId" returned an invalid generation', error, stackTrace);
      await _discardStartedPlugin(slot: slot, pluginId: pluginId, plugin: started);
      return null;
    }
  }

  Future<void> _discardStartedPlugin({
    required _PluginRuntimeSlot slot,
    required String pluginId,
    required BridgePlugin plugin,
  }) async {
    if (identical(slot.plugin, plugin)) slot.plugin = null;
    try {
      await _cancelGenerationSubscriptions(slot);
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" subscription cleanup after a failed start also failed', error, stackTrace);
    }
    await _shutdownFailedStart(pluginId: pluginId, plugin: plugin);
  }

  Future<void> _shutdownFailedStart({required String pluginId, required BridgePlugin plugin}) async {
    try {
      await plugin.shutdown(budget: _shutdownBudget);
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" cleanup after a failed start also failed', error, stackTrace);
    }
  }

  void _validateStartedPlugin({required _PluginRuntimeSlot slot, required BridgePlugin plugin}) {
    final descriptor = slot.registration.descriptor;
    if (plugin.api.id != descriptor.id) {
      throw StateError('Plugin "${descriptor.id}" returned API id "${plugin.api.id}".');
    }
    final matchesOwnership = switch (descriptor.projectOwnership) {
      PluginProjectOwnership.native => plugin.api is NativeProjectsPluginApi,
      PluginProjectOwnership.bridgeDerived => plugin.api is BridgeDerivedProjectsPluginApi,
    };
    if (!matchesOwnership) {
      throw StateError('Plugin "${descriptor.id}" returned an API that contradicts its project ownership declaration.');
    }
  }

  void _applyStatus({
    required _PluginRuntimeSlot slot,
    required int generation,
    required PluginStatus status,
  }) {
    if (slot.generation != generation) return;
    if (_shuttingDown) return;
    if (status case PluginFailed(:final reason, :final cause)) {
      Log.w('Plugin "${slot.registration.descriptor.id}" failed after startup: $reason', cause);
      _retireFailedGeneration(slot: slot, generation: generation, reason: reason);
      return;
    }
    if (status is PluginStopped) {
      _retireFailedGeneration(slot: slot, generation: generation, reason: "plugin stopped");
      return;
    }
    if (status is PluginStopping) {
      slot.state = PluginRuntimeState.stopping;
      if (slot.commandTransition == null) {
        slot.transition = PluginRuntimeTransition.stopping;
      }
      _publishSnapshots();
      return;
    }
    slot.state = switch (status) {
      PluginStarting() || PluginReady() => PluginRuntimeState.active,
      PluginDegraded() || PluginRestarting() => PluginRuntimeState.degraded,
      PluginStopping() => throw StateError("handled above"),
      PluginFailed() || PluginStopped() => throw StateError("handled above"),
    };
    _publishSnapshots();
  }

  void _retireFailedGeneration({
    required _PluginRuntimeSlot slot,
    required int generation,
    required String reason,
  }) {
    if (slot.generation != generation) return;
    final plugin = slot.plugin;
    if (plugin == null || slot.cleanupFuture != null) return;
    slot
      ..state = PluginRuntimeState.stopping
      ..workState = PluginWorkState.unknown;
    if (slot.commandTransition == null) {
      slot.transition = PluginRuntimeTransition.stopping;
    }
    _publishSnapshots();

    late final Future<void> cleanup;
    cleanup = () async {
      try {
        await _waitForDurableCommits(slot);
        if (slot.generation != generation || !identical(slot.plugin, plugin)) return;
        slot
          ..plugin = null
          ..state = PluginRuntimeState.failed
          ..workState = PluginWorkState.unknown;
        _publishSnapshots();
        await _cancelAndShutdownGeneration(slot: slot, plugin: plugin);
      } on Object catch (error, stackTrace) {
        Log.w(
          'Plugin "${slot.registration.descriptor.id}" cleanup after $reason failed',
          error,
          stackTrace,
        );
      } finally {
        try {
          await slot.startFuture;
        } on Object {
          // The initiating start failure is already surfaced by its owner.
        }
        if (identical(slot.cleanupFuture, cleanup)) slot.cleanupFuture = null;
        if (slot.commandTransition == null &&
            slot.generation == generation &&
            slot.transition == PluginRuntimeTransition.stopping) {
          slot.transition = PluginRuntimeTransition.none;
        }
        _publishSnapshots();
      }
    }();
    slot.cleanupFuture = cleanup;
    unawaited(cleanup);
  }

  void _handleAuthenticationRequired({
    required _PluginLease lease,
    required PluginAuthenticationRequiredException failure,
  }) {
    _handleGenerationAuthenticationRequired(
      slot: lease.slot,
      generation: lease.generation,
      api: lease.api,
      failure: failure,
    );
  }

  void _handleGenerationAuthenticationRequired({
    required _PluginRuntimeSlot slot,
    required int generation,
    required BridgePluginApi api,
    required PluginAuthenticationRequiredException failure,
  }) {
    if (slot.generation != generation || !identical(slot.plugin?.api, api)) return;
    slot.setupInspectionRevision++;
    slot
      ..setup = PluginSetupAuthenticationRequired(actionHint: failure.actionHint)
      ..startAllowed = false
      ..workState = PluginWorkState.unknown;
    final plugin = slot.plugin;
    if (plugin == null) {
      _publishSnapshots();
      return;
    }
    if (slot.cleanupFuture != null && slot.transition == PluginRuntimeTransition.stopping) {
      _publishSnapshots();
      return;
    }
    slot
      ..state = PluginRuntimeState.stopping
      ..transition = PluginRuntimeTransition.stopping;
    _publishSnapshots();

    late final Future<void> cleanup;
    cleanup = () async {
      try {
        // A stream-originated auth failure must finish retaining its terminal
        // future before generation cancellation can re-enter that stream.
        await Future<void>.value();
        await _cancelOperationStreams(slot);
        await _waitForLeaseDrain(slot);
        if (slot.generation != generation || !identical(slot.plugin, plugin)) return;
        slot.plugin = null;
        _publishSnapshots();
        await _cancelAndShutdownGeneration(slot: slot, plugin: plugin);
      } on Object catch (error, stackTrace) {
        Log.w('Plugin "${slot.registration.descriptor.id}" auth-loss cleanup failed', error, stackTrace);
      } finally {
        if (identical(slot.cleanupFuture, cleanup)) slot.cleanupFuture = null;
        if (slot.generation == generation) {
          slot
            ..state = PluginRuntimeState.blocked
            ..workState = PluginWorkState.unknown;
          if (slot.commandTransition == null) {
            slot.transition = PluginRuntimeTransition.none;
          }
        }
        _publishSnapshots();
      }
    }();
    slot.cleanupFuture = cleanup;
    unawaited(cleanup);
  }

  Future<void> _cancelOperationStreams(_PluginRuntimeSlot slot) async {
    final cancellations = slot.operationStreamCancellations.toList(growable: false);
    slot.operationStreamCancellations.clear();
    await Future.wait([for (final cancel in cancellations) cancel()]);
  }

  bool _isPendingInputResolution(BridgeSseEvent event) {
    return event is BridgeSsePermissionReplied ||
        event is BridgeSseQuestionReplied ||
        event is BridgeSseQuestionRejected;
  }

  Future<void> _cancelGenerationSubscriptions(_PluginRuntimeSlot slot) async {
    final subscriptions = [slot.statusSubscription, slot.workSubscription, slot.eventSubscription];
    slot
      ..statusSubscription = null
      ..workSubscription = null
      ..eventSubscription = null;
    await Future.wait([
      _cancelOperationStreams(slot),
      for (final subscription in subscriptions)
        if (subscription != null) subscription.cancel(),
    ]);
  }

  Future<void> _cancelAndShutdownGeneration({
    required _PluginRuntimeSlot slot,
    required BridgePlugin? plugin,
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _cancelGenerationSubscriptions(slot);
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await plugin?.shutdown(budget: _shutdownBudget);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  bool _isRoutable(_PluginRuntimeSlot slot) {
    return slot.accessGate == PluginRuntimeAccessGate.enabled &&
        slot.startAllowed &&
        !_blocksAcquisition(slot) &&
        _hasOperationalGeneration(slot);
  }

  bool _hasOperationalGeneration(_PluginRuntimeSlot slot) {
    return slot.plugin != null &&
        (slot.state == PluginRuntimeState.active || slot.state == PluginRuntimeState.degraded);
  }

  bool _blocksAcquisition(_PluginRuntimeSlot slot) {
    return switch (slot.transition) {
      PluginRuntimeTransition.none || PluginRuntimeTransition.starting => false,
      PluginRuntimeTransition.stopping || PluginRuntimeTransition.restarting => true,
    };
  }

  _PluginRuntimeSlot _requireSlot(String pluginId) {
    final slot = _slots[pluginId];
    if (slot == null) throw ArgumentError.value(pluginId, "pluginId", "is not registered");
    return slot;
  }

  _PluginRuntimeSlot _requireOperationSlot({required String pluginId, required Enum operation}) {
    final slot = _slots[pluginId];
    if (slot == null) {
      throw PluginOperationException(
        operation.name,
        statusCode: 503,
        message: "plugin $pluginId is unknown and unavailable",
      );
    }
    return slot;
  }

  List<PluginRuntimeSnapshot> _buildSnapshots() => List<PluginRuntimeSnapshot>.unmodifiable([
    for (final slot in _slots.values) _snapshotFor(slot),
  ]);

  PluginRuntimeSnapshot _snapshotFor(_PluginRuntimeSlot slot) {
    final state = switch (slot.accessGate) {
      PluginRuntimeAccessGate.disabled => PluginRuntimeState.disabled,
      PluginRuntimeAccessGate.draining => PluginRuntimeState.stopping,
      PluginRuntimeAccessGate.enabled when !slot.startAllowed => PluginRuntimeState.blocked,
      PluginRuntimeAccessGate.enabled
          when slot.plugin == null && slot.startFuture == null && slot.state != PluginRuntimeState.failed =>
        PluginRuntimeState.dormant,
      PluginRuntimeAccessGate.enabled => slot.state,
    };
    return PluginRuntimeSnapshot(
      pluginId: slot.registration.descriptor.id,
      projectOwnership: slot.registration.descriptor.projectOwnership,
      setup: slot.setup,
      accessGate: slot.accessGate,
      startAllowed: slot.startAllowed,
      generation: slot.generation,
      state: state,
      workState: slot.workState,
      leaseCount: slot.leaseCount,
      transition: slot.transition,
    );
  }

  void _publishSnapshots() {
    if (!_snapshotsSubject.isClosed) _snapshotsSubject.add(_buildSnapshots());
  }
}

typedef _CommandTransition = ({Object owner, Completer<void> completer});

class _PluginRuntimeSlot({required final PluginRuntimeRegistration registration}) {
  PluginSetupStatus setup = const PluginSetupUnknown(actionHint: null);
  PluginRuntimeAccessGate accessGate = PluginRuntimeAccessGate.disabled;
  bool startAllowed = false;
  int setupInspectionRevision = 0;
  int? generation;
  PluginRuntimeState state = PluginRuntimeState.disabled;
  PluginWorkState workState = PluginWorkState.unknown;
  PluginRuntimeTransition transition = PluginRuntimeTransition.none;
  _CommandTransition? commandTransition;
  int leaseCount = 0;
  int durableCommitCount = 0;
  Completer<void>? durableCommitsDrained;
  Completer<void>? leaseDrainCompleter;
  BridgePlugin? plugin;
  Future<BridgePlugin?>? startFuture;
  Future<void>? cleanupFuture;
  StartAbortController? startAbortController;
  // ignore: cancel_subscriptions - generation ownership cancels these in PluginRuntime.
  StreamSubscription<PluginStatus>? statusSubscription;
  // ignore: cancel_subscriptions - generation ownership cancels these in PluginRuntime.
  StreamSubscription<PluginWorkState>? workSubscription;
  // ignore: cancel_subscriptions - generation ownership cancels these in PluginRuntime.
  StreamSubscription<BridgeSseEvent>? eventSubscription;
  bool allowPendingInputResolutionsDuringStop = false;
  final Set<Future<void> Function()> operationStreamCancellations = <Future<void> Function()>{};
}

class const _PluginLease({required final _PluginRuntimeSlot slot, required final int generation, required final BridgePluginApi api});
