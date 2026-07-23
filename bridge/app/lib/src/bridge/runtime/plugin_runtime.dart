import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "plugin_generation_factory.dart";

class PluginRuntimeAccess {
  const PluginRuntimeAccess({
    required this.pluginId,
    required this.eligible,
    required this.startAllowed,
  });

  final String pluginId;
  final bool eligible;
  final bool startAllowed;
}

enum PluginRuntimeState { disabled, blocked, dormant, starting, active, degraded, stopping, failed }

enum PluginRuntimeTransition { none, starting, stopping, restarting }

enum PluginStopIntent { safe, force }

enum PluginRuntimeConflictReason { inFlight, transitioning, notEligible }

class PluginRuntimeSnapshot {
  const PluginRuntimeSnapshot({
    required this.pluginId,
    required this.projectOwnership,
    required this.setup,
    required this.eligible,
    required this.startAllowed,
    required this.generation,
    required this.state,
    required this.leaseCount,
    required this.transition,
  });

  final String pluginId;
  final PluginProjectOwnership projectOwnership;
  final PluginSetupStatus setup;
  final bool eligible;
  final bool startAllowed;
  final int? generation;
  final PluginRuntimeState state;
  final int leaseCount;
  final PluginRuntimeTransition transition;
}

typedef SourcedPluginRuntimeEvent = ({String pluginId, int generation, BridgeSseEvent event});
typedef SourcedPluginProvisionProgress = ({String pluginId, RuntimeProvisionProgress event});

sealed class PluginRuntimeCommandResult {
  const PluginRuntimeCommandResult({required this.snapshot});

  final PluginRuntimeSnapshot snapshot;
}

final class PluginRuntimeCommandApplied extends PluginRuntimeCommandResult {
  const PluginRuntimeCommandApplied({required super.snapshot});
}

final class PluginRuntimeCommandCurrent extends PluginRuntimeCommandResult {
  const PluginRuntimeCommandCurrent({required super.snapshot});
}

final class PluginRuntimeCommandConflict extends PluginRuntimeCommandResult {
  const PluginRuntimeCommandConflict({required super.snapshot, required this.reasons});

  final List<PluginRuntimeConflictReason> reasons;
}

final class PluginRuntimeCommandFailed extends PluginRuntimeCommandResult {
  const PluginRuntimeCommandFailed({required super.snapshot, required this.message});

  final String message;
}

class PluginRuntime {
  PluginRuntime({
    required List<PluginRuntimeRegistration> registrations,
    required PluginGenerationFactory generationFactory,
    required HostProcessService setupProcesses,
    required Map<String, String> environment,
    required ServerClock clock,
    required Duration shutdownBudget,
  }) : _generationFactory = generationFactory,
       _setupProcesses = setupProcesses,
       _environment = Map<String, String>.unmodifiable(environment),
       _clock = clock,
       _shutdownBudget = shutdownBudget,
       _slots = <String, _PluginRuntimeSlot>{
         for (final registration in registrations)
           registration.descriptor.id: _PluginRuntimeSlot(registration: registration),
       } {
    if (_slots.length != registrations.length) {
      throw ArgumentError.value(registrations, "registrations", "must not contain duplicate plugin ids");
    }
    _snapshotsSubject = BehaviorSubject<List<PluginRuntimeSnapshot>>.seeded(_buildSnapshots());
  }

  final PluginGenerationFactory _generationFactory;
  final HostProcessService _setupProcesses;
  final Map<String, String> _environment;
  final ServerClock _clock;
  final Duration _shutdownBudget;
  final Map<String, _PluginRuntimeSlot> _slots;
  late final BehaviorSubject<List<PluginRuntimeSnapshot>> _snapshotsSubject;
  final PublishSubject<SourcedPluginRuntimeEvent> _backendEventsSubject = PublishSubject<SourcedPluginRuntimeEvent>();
  final PublishSubject<SourcedPluginProvisionProgress> _provisionProgressSubject =
      PublishSubject<SourcedPluginProvisionProgress>();
  bool _shuttingDown = false;
  Future<void>? _disposeStartedApisFuture;
  Future<void>? _disposeFuture;
  bool _apiDisposalStarted = false;
  final Map<BridgePluginApi, Future<void>> _apiDisposals = Map<BridgePluginApi, Future<void>>.identity();

  Stream<List<PluginRuntimeSnapshot>> get snapshots => _snapshotsSubject.stream;
  List<PluginRuntimeSnapshot> get snapshot => List<PluginRuntimeSnapshot>.unmodifiable(_buildSnapshots());
  Stream<SourcedPluginRuntimeEvent> get backendEvents => _backendEventsSubject.stream;
  Stream<SourcedPluginProvisionProgress> get provisionProgress => _provisionProgressSubject.stream;

  Set<String> get activePluginIds => {
    for (final slot in _slots.values)
      if (_isRoutable(slot)) slot.registration.descriptor.id,
  };

  Set<String> get startAllowedPluginIds => {
    for (final slot in _slots.values)
      if (slot.eligible && slot.startAllowed) slot.registration.descriptor.id,
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
          slot.setup = const PluginSetupNotInspected();
        }
      }
    }
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
      _slots[result.pluginId]!.setup = result.setup;
    }
    _publishSnapshots();
    return Map<String, PluginSetupStatus>.unmodifiable({
      for (final slot in _slots.values) slot.registration.descriptor.id: slot.setup,
    });
  }

  void applyAccess({required List<PluginRuntimeAccess> entries}) {
    final byId = <String, PluginRuntimeAccess>{for (final entry in entries) entry.pluginId: entry};
    if (byId.length != entries.length || byId.keys.toSet().difference(_slots.keys.toSet()).isNotEmpty) {
      throw ArgumentError.value(entries, "entries", "must contain unique registered plugin ids");
    }
    for (final slot in _slots.values) {
      final entry = byId[slot.registration.descriptor.id];
      slot
        ..eligible = entry?.eligible ?? false
        ..startAllowed = entry?.startAllowed ?? false;
    }
    _publishSnapshots();
  }

  Future<void> startEager({required List<String> pluginIds}) async {
    final starts = <Future<BridgePlugin?>>[];
    for (final pluginId in pluginIds) {
      starts.add(_ensureStarted(slot: _requireSlot(pluginId)));
    }
    await Future.wait(starts);
  }

  Future<T> use<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api) body,
  }) {
    return useWithGeneration(
      pluginId: pluginId,
      operation: operation,
      body: (api, _) => body(api),
    );
  }

  Future<T> useWithGeneration<T>({
    required String pluginId,
    required Enum operation,
    required Future<T> Function(BridgePluginApi api, int generation) body,
  }) async {
    final lease = await _acquire(pluginId: pluginId, operation: operation, startIfNeeded: true);
    try {
      final result = await body(lease.api, lease.generation);
      _requireCurrentGeneration(lease: lease, operation: operation);
      return result;
    } finally {
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

    Future<void> finish({Object? error, StackTrace? stackTrace, required bool cancelSource}) {
      return termination ??= () async {
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
          releaseLease();
          if (!cancelled && !controller.isClosed) await controller.close();
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
        try {
          await sourceSubscription?.cancel();
        } finally {
          releaseLease();
        }
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
    } finally {
      _release(lease);
    }
  }

  bool isCurrentGeneration({required String pluginId, required int generation}) {
    final slot = _slots[pluginId];
    return slot != null && slot.generation == generation && _isRoutable(slot);
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
    if (!slot.eligible) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.notEligible],
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
  }) => _stop(pluginId: pluginId, intent: intent);

  Future<PluginRuntimeCommandResult> restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) => _restart(pluginId: pluginId, intent: intent);

  void beginShutdown() {
    if (_shuttingDown) return;
    _shuttingDown = true;
    for (final slot in _slots.values) {
      slot.startAbortController?.abort();
    }
  }

  Future<void> disposeStartedApis() => _disposeStartedApisFuture ??= _disposeStartedApis();

  Future<void> _disposeStartedApis() async {
    _apiDisposalStarted = true;
    final errors = <({Object error, StackTrace stackTrace})>[];

    Future<void> capture(Future<void> operation) async {
      try {
        await operation;
      } on PluginStartAbortedException {
        // Expected when beginShutdown aborts an in-flight generation start.
      } on Object catch (error, stackTrace) {
        errors.add((error: error, stackTrace: stackTrace));
      }
    }

    final starts = [for (final slot in _slots.values) ?slot.startFuture];
    await Future.wait([
      for (final slot in _slots.values)
        if (slot.plugin case final plugin?) capture(_disposeApi(plugin.api)),
      for (final start in starts) capture(start.then<void>((_) {})),
    ]);
    await Future.wait([
      for (final slot in _slots.values)
        if (slot.plugin case final plugin?) capture(_disposeApi(plugin.api)),
    ]);
    if (errors case [final first, ...]) {
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  Future<void> _disposeApi(BridgePluginApi api) {
    return _apiDisposals.putIfAbsent(api, () => Future<void>.sync(api.dispose));
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

  Future<PluginRuntimeCommandResult> _stop({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    final slot = _requireSlot(pluginId);
    if (!slot.eligible) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.notEligible],
      );
    }
    final forceCanTakeOverTransition =
        intent == PluginStopIntent.force &&
        slot.commandTransitionOwner == null &&
        slot.cleanupFuture == null &&
        (slot.transition == PluginRuntimeTransition.starting ||
            (slot.transition == PluginRuntimeTransition.stopping && slot.plugin != null));
    if (slot.commandTransitionOwner != null ||
        (slot.transition != PluginRuntimeTransition.none && !forceCanTakeOverTransition)) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    if (intent == PluginStopIntent.safe && slot.leaseCount > 0) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.inFlight],
      );
    }
    final hadPlugin = slot.plugin != null || slot.startFuture != null;
    final transitionOwner = Object();
    slot
      ..commandTransitionOwner = transitionOwner
      ..transition = PluginRuntimeTransition.stopping;
    _publishSnapshots();
    String? failureMessage;
    try {
      await _stopCurrentGeneration(slot: slot, intent: intent);
      if (!identical(slot.commandTransitionOwner, transitionOwner)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.dormant;
    } on Object catch (error) {
      if (!identical(slot.commandTransitionOwner, transitionOwner)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.failed;
      failureMessage = "$error";
    } finally {
      if (identical(slot.commandTransitionOwner, transitionOwner)) {
        slot
          ..commandTransitionOwner = null
          ..transition = PluginRuntimeTransition.none;
      }
      _publishSnapshots();
    }
    if (failureMessage != null) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: failureMessage);
    }
    return hadPlugin
        ? PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot))
        : PluginRuntimeCommandCurrent(snapshot: _snapshotFor(slot));
  }

  Future<PluginRuntimeCommandResult> _restart({
    required String pluginId,
    required PluginStopIntent intent,
  }) async {
    final slot = _requireSlot(pluginId);
    if (!slot.eligible) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.notEligible],
      );
    }
    final forceCanTakeOverTransition =
        intent == PluginStopIntent.force &&
        slot.commandTransitionOwner == null &&
        slot.cleanupFuture == null &&
        (slot.transition == PluginRuntimeTransition.starting ||
            (slot.transition == PluginRuntimeTransition.stopping && slot.plugin != null));
    if (slot.commandTransitionOwner != null ||
        (slot.transition != PluginRuntimeTransition.none && !forceCanTakeOverTransition)) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.transitioning],
      );
    }
    if (intent == PluginStopIntent.safe && slot.leaseCount > 0) {
      return PluginRuntimeCommandConflict(
        snapshot: _snapshotFor(slot),
        reasons: const [PluginRuntimeConflictReason.inFlight],
      );
    }

    final transitionOwner = Object();
    slot
      ..commandTransitionOwner = transitionOwner
      ..transition = PluginRuntimeTransition.restarting;
    _publishSnapshots();
    String? failureMessage;
    try {
      await _stopCurrentGeneration(slot: slot, intent: intent);
      if (!identical(slot.commandTransitionOwner, transitionOwner)) {
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
        if (!identical(slot.commandTransitionOwner, transitionOwner)) {
          return PluginRuntimeCommandConflict(
            snapshot: _snapshotFor(slot),
            reasons: const [PluginRuntimeConflictReason.transitioning],
          );
        }
        if (plugin == null || !_hasOperationalGeneration(slot)) failureMessage = "plugin failed to restart";
      }
    } on Object catch (error) {
      if (!identical(slot.commandTransitionOwner, transitionOwner)) {
        return PluginRuntimeCommandConflict(
          snapshot: _snapshotFor(slot),
          reasons: const [PluginRuntimeConflictReason.transitioning],
        );
      }
      slot.state = PluginRuntimeState.failed;
      failureMessage = "$error";
    } finally {
      if (identical(slot.commandTransitionOwner, transitionOwner)) {
        slot
          ..commandTransitionOwner = null
          ..transition = PluginRuntimeTransition.none;
      }
      _publishSnapshots();
    }
    if (failureMessage != null) {
      return PluginRuntimeCommandFailed(snapshot: _snapshotFor(slot), message: failureMessage);
    }
    return PluginRuntimeCommandApplied(snapshot: _snapshotFor(slot));
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
    slot
      ..plugin = null
      ..state = PluginRuntimeState.stopping;
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

  Future<_PluginLease> _acquire({
    required String pluginId,
    required Enum operation,
    required bool startIfNeeded,
  }) async {
    if (_shuttingDown) {
      throw PluginOperationException(operation.name, statusCode: 503, message: "bridge is shutting down");
    }
    final slot = _requireOperationSlot(pluginId: pluginId, operation: operation);
    if (!slot.eligible || !slot.startAllowed) {
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
    _publishSnapshots();
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

  Future<BridgePlugin?> _ensureStarted({required _PluginRuntimeSlot slot}) {
    if (_isRoutable(slot)) return Future<BridgePlugin?>.value(slot.plugin);
    final existing = slot.startFuture;
    if (existing != null) return existing;
    if (_shuttingDown || !slot.eligible || !slot.startAllowed || slot.transition != PluginRuntimeTransition.none) {
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
    Log.v('Starting plugin "$pluginId" generation at ${_clock.now().toIso8601String()}');
    final generation = (slot.generation ?? 0) + 1;
    final abortController = StartAbortController();
    slot
      ..generation = generation
      ..transition = transition
      ..state = PluginRuntimeState.starting
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
      // ignore: cancel_subscriptions - retained by the slot and cancelled when this generation stops.
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
      // ignore: cancel_subscriptions - retained by the slot and cancelled when this generation stops.
      slot.eventSubscription = started.api.events.listen(
        (event) {
          if (slot.generation == generation && !_backendEventsSubject.isClosed) {
            _backendEventsSubject.add((pluginId: pluginId, generation: generation, event: event));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_shuttingDown) return;
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
      if (_apiDisposalStarted) await _disposeApi(started.api);
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
      if (slot.commandTransitionOwner == null) {
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
    if (plugin == null) return;
    slot
      ..plugin = null
      ..state = PluginRuntimeState.failed;
    if (slot.commandTransitionOwner == null) {
      slot.transition = PluginRuntimeTransition.stopping;
    }
    _publishSnapshots();

    late final Future<void> cleanup;
    cleanup = () async {
      try {
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
        if (slot.commandTransitionOwner == null &&
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

  Future<void> _cancelGenerationSubscriptions(_PluginRuntimeSlot slot) async {
    final subscriptions = [slot.statusSubscription, slot.eventSubscription];
    slot
      ..statusSubscription = null
      ..eventSubscription = null;
    await Future.wait([
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
    return slot.eligible && !_blocksAcquisition(slot) && _hasOperationalGeneration(slot);
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

  List<PluginRuntimeSnapshot> _buildSnapshots() => [for (final slot in _slots.values) _snapshotFor(slot)];

  PluginRuntimeSnapshot _snapshotFor(_PluginRuntimeSlot slot) {
    final state = !slot.eligible
        ? PluginRuntimeState.disabled
        : !slot.startAllowed
        ? PluginRuntimeState.blocked
        : slot.plugin == null && slot.startFuture == null && slot.state != PluginRuntimeState.failed
        ? PluginRuntimeState.dormant
        : slot.state;
    return PluginRuntimeSnapshot(
      pluginId: slot.registration.descriptor.id,
      projectOwnership: slot.registration.descriptor.projectOwnership,
      setup: slot.setup,
      eligible: slot.eligible,
      startAllowed: slot.startAllowed,
      generation: slot.generation,
      state: state,
      leaseCount: slot.leaseCount,
      transition: slot.transition,
    );
  }

  void _publishSnapshots() {
    if (!_snapshotsSubject.isClosed) _snapshotsSubject.add(_buildSnapshots());
  }
}

class _PluginRuntimeSlot {
  _PluginRuntimeSlot({required this.registration});

  final PluginRuntimeRegistration registration;
  PluginSetupStatus setup = const PluginSetupUnknown(actionHint: null);
  bool eligible = false;
  bool startAllowed = false;
  int? generation;
  PluginRuntimeState state = PluginRuntimeState.disabled;
  PluginRuntimeTransition transition = PluginRuntimeTransition.none;
  Object? commandTransitionOwner;
  int leaseCount = 0;
  BridgePlugin? plugin;
  Future<BridgePlugin?>? startFuture;
  Future<void>? cleanupFuture;
  StartAbortController? startAbortController;
  // ignore: cancel_subscriptions - generation ownership cancels these in PluginRuntime.
  StreamSubscription<PluginStatus>? statusSubscription;
  // ignore: cancel_subscriptions - generation ownership cancels these in PluginRuntime.
  StreamSubscription<BridgeSseEvent>? eventSubscription;
}

class _PluginLease {
  const _PluginLease({required this.slot, required this.generation, required this.api});

  final _PluginRuntimeSlot slot;
  final int generation;
  final BridgePluginApi api;
}
