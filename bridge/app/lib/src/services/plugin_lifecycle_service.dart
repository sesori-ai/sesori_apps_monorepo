import "dart:async";
import "dart:collection";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

typedef PluginCompositionView = ({
  Set<String> knownPluginIds,
  List<String> enabledPluginIds,
  String? defaultEnabledPluginId,
  Map<String, BridgePluginApi> operationalPlugins,
});

typedef EnabledPluginRegistration = ({String id, String displayName, bool isDefault});
typedef RegisteredPluginMetadata = ({String id, String displayName});

typedef EffectivePluginSelection = ({
  List<String> enabledPluginIds,
  List<String> eagerPluginIds,
  String? defaultPluginId,
});

class PluginLifecycleService {
  PluginLifecycleService();

  final Map<String, BridgePluginApi> _operationalPlugins = <String, BridgePluginApi>{};
  final Map<String, _StartedPlugin> _startedPlugins = <String, _StartedPlugin>{};
  final Map<String, Future<void>> _startSettlements = <String, Future<void>>{};
  final Map<String, StreamSubscription<PluginStatus>> _statusSubscriptions =
      <String, StreamSubscription<PluginStatus>>{};
  final Map<BridgePluginApi, Future<void>> _earlyDisposals = <BridgePluginApi, Future<void>>{};

  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  List<EnabledPluginRegistration>? _enabledPlugins;
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  EffectivePluginSelection? _effectiveSelection;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  bool _earlyDisposeStarted = false;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  void registerPlugins({required List<RegisteredPluginMetadata> plugins}) {
    if (_registeredPlugins != null) {
      throw StateError("Plugins are already registered.");
    }
    final ids = plugins.map((plugin) => plugin.id).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(plugins, "plugins", "must not contain duplicate ids");
    }
    final sortedPlugins = [...plugins]
      ..sort((left, right) {
        final byName = left.displayName.toLowerCase().compareTo(right.displayName.toLowerCase());
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
    _registeredPlugins = List<RegisteredPluginMetadata>.unmodifiable(sortedPlugins);
    _knownPluginIds = Set<String>.unmodifiable(ids);
  }

  EffectivePluginSelection initialize({
    required Set<String> disabledPluginIds,
    required Map<String, PluginSetupStatus> setupById,
  }) {
    if (_enabledPlugins != null) {
      throw StateError("Plugin lifecycle is already initialized.");
    }
    final registeredPlugins = _registeredPlugins;
    final knownPluginIds = _knownPluginIds;
    if (registeredPlugins == null || knownPluginIds == null) {
      throw StateError("Plugins have not been registered.");
    }
    if (setupById.keys.toSet().difference(knownPluginIds).isNotEmpty ||
        knownPluginIds.difference(setupById.keys.toSet()).isNotEmpty) {
      throw ArgumentError.value(setupById, "setupById", "must contain exactly every registered plugin id");
    }
    _setupById = Map<String, PluginSetupStatus>.unmodifiable(setupById);

    final selection = _resolveSelection(
      disabledPluginIds: disabledPluginIds,
      registeredPlugins: registeredPlugins,
      setupById: setupById,
    );
    _effectiveSelection = selection;
    final enabledPlugins = [
      for (final id in selection.enabledPluginIds)
        (
          id: id,
          displayName: registeredPlugins.singleWhere((plugin) => plugin.id == id).displayName,
          isDefault: id == selection.defaultPluginId,
        ),
    ];
    final enabledIds = enabledPlugins.map((plugin) => plugin.id).toList(growable: false);
    if (enabledIds.toSet().length != enabledIds.length) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "must not contain duplicate ids");
    }
    final defaultCount = enabledPlugins.where((plugin) => plugin.isDefault).length;
    if (defaultCount > 1 || (selection.defaultPluginId != null && defaultCount != 1)) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "must contain at most one valid default plugin");
    }
    if (!knownPluginIds.containsAll(enabledIds)) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "contains an unknown plugin id");
    }

    _enabledPlugins = List<EnabledPluginRegistration>.unmodifiable(enabledPlugins);
    _metadataById = <String, PluginMetadata>{
      for (final plugin in enabledPlugins)
        plugin.id: PluginMetadata(
          id: plugin.id,
          displayName: plugin.displayName,
          isDefault: plugin.isDefault,
          state: PluginLifecycleState.unavailable,
          actionHint: _actionHint(PluginLifecycleState.unavailable),
        ),
    };
    _metadataSubject = BehaviorSubject<List<PluginMetadata>>.seeded(_orderedMetadata());
    return selection;
  }

  EffectivePluginSelection get effectiveSelection {
    final selection = _effectiveSelection;
    if (selection == null) throw StateError("Plugin lifecycle has not been initialized.");
    return selection;
  }

  PluginCompositionView get compositionView {
    final knownPluginIds = _knownPluginIds;
    final enabledPlugins = _enabledPlugins;
    if (knownPluginIds == null || enabledPlugins == null) {
      throw StateError("Plugin selection has not been registered.");
    }
    return (
      knownPluginIds: knownPluginIds,
      enabledPluginIds: List<String>.unmodifiable(enabledPlugins.map((plugin) => plugin.id)),
      defaultEnabledPluginId: _routableDefaultPluginId(),
      operationalPlugins: UnmodifiableMapView<String, BridgePluginApi>(_operationalPlugins),
    );
  }

  List<PluginMetadata> get metadataSnapshot => List<PluginMetadata>.unmodifiable(_orderedMetadata());

  /// Enabled choices a released new-session client can route immediately.
  List<PluginMetadata> get selectableMetadataSnapshot {
    final selection = _effectiveSelection;
    if (selection == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    final selectable = [
      for (final metadata in _orderedMetadata())
        if (_operationalPlugins.containsKey(metadata.id)) metadata,
    ];
    final selectableDefaultId = _routableDefaultPluginId();
    return List<PluginMetadata>.unmodifiable([
      for (final metadata in selectable) metadata.copyWith(isDefault: metadata.id == selectableDefaultId),
    ]);
  }

  PluginSetupResponse get setupSnapshot {
    final registeredPlugins = _registeredPlugins;
    final setupById = _setupById;
    if (registeredPlugins == null || setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    return PluginSetupResponse(
      plugins: [
        for (final plugin in registeredPlugins) _mapSetupMetadata(plugin: plugin, setup: setupById[plugin.id]!),
      ],
    );
  }

  Stream<List<PluginMetadata>> get metadataSnapshots {
    final subject = _metadataSubject;
    if (subject == null) {
      throw StateError("Plugin selection has not been registered.");
    }
    return subject.stream;
  }

  void registerUnavailable({required String id}) {
    _requireEnabled(id);
    _operationalPlugins.remove(id);
    _publishState(id: id, state: PluginLifecycleState.unavailable);
  }

  Future<void> registerStart({
    required String id,
    required Future<BridgePlugin> startFuture,
    required Duration shutdownBudget,
  }) {
    _requireEnabled(id);
    if (_startSettlements.containsKey(id)) {
      throw StateError('Plugin "$id" already has a registered start.');
    }
    final settlement = _settleStart(
      id: id,
      startFuture: startFuture,
      shutdownBudget: shutdownBudget,
    );
    _startSettlements[id] = settlement;
    return settlement;
  }

  Future<void> _settleStart({
    required String id,
    required Future<BridgePlugin> startFuture,
    required Duration shutdownBudget,
  }) async {
    final BridgePlugin plugin;
    try {
      plugin = await startFuture;
    } on PluginStartAbortedException {
      _publishState(id: id, state: PluginLifecycleState.failed);
      rethrow;
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$id" failed to start', error, stackTrace);
      _publishState(id: id, state: PluginLifecycleState.failed);
      return;
    }

    _startedPlugins[id] = _StartedPlugin(plugin: plugin, shutdownBudget: shutdownBudget);
    if (plugin.api.id != id) {
      _operationalPlugins.remove(id);
      _publishState(id: id, state: PluginLifecycleState.failed);
      if (_earlyDisposeStarted) await _disposeApi(plugin.api);
      return;
    }

    // ignore: cancel_subscriptions - retained and cancelled by dispose().
    final subscription = plugin.status.listen(
      (status) => _applyStatus(id: id, api: plugin.api, status: status),
      onError: (Object error, StackTrace stackTrace) {
        Log.w('Plugin "$id" status stream failed', error, stackTrace);
        _operationalPlugins.remove(id);
        _publishState(id: id, state: PluginLifecycleState.failed);
      },
    );
    _statusSubscriptions[id] = subscription;
    _applyStatus(id: id, api: plugin.api, status: plugin.currentStatus);
    if (_earlyDisposeStarted) await _disposeApi(plugin.api);
  }

  void _applyStatus({required String id, required BridgePluginApi api, required PluginStatus status}) {
    if (status case PluginFailed(:final reason, :final cause)) {
      Log.w('Plugin "$id" failed after startup: $reason', cause);
    }
    final state = switch (status) {
      PluginStarting() || PluginReady() => PluginLifecycleState.ready,
      PluginDegraded() || PluginRestarting() || PluginStopping() => PluginLifecycleState.degraded,
      PluginFailed() || PluginStopped() => PluginLifecycleState.failed,
    };
    if (state == PluginLifecycleState.failed) {
      _operationalPlugins.remove(id);
    } else {
      _operationalPlugins[id] = api;
    }
    _publishState(id: id, state: state);
  }

  Future<void> disposeStartedApis() async {
    _earlyDisposeStarted = true;
    final settlements = _startSettlements.values.toList(growable: false);
    final instances = _startedPlugins.values.toList(growable: false);
    final errors = <({Object error, StackTrace stackTrace})>[];

    Future<void> capture(Future<void> operation) async {
      try {
        await operation;
      } on PluginStartAbortedException {
        // The runner owns whether an aborted start is expected for this run.
      } on Object catch (error, stackTrace) {
        errors.add((error: error, stackTrace: stackTrace));
      }
    }

    // Launch disposal for every API already returned before waiting for starts
    // that may remain blocked. Late returns observe _earlyDisposeStarted in
    // _settleStart and dispose before their registration settles.
    await Future.wait(
      [
        for (final started in instances) capture(_disposeApi(started.plugin.api)),
        for (final settlement in settlements) capture(settlement),
      ],
    );
    if (errors case [final first, ...]) {
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  Future<void> _disposeApi(BridgePluginApi api) {
    return _earlyDisposals.putIfAbsent(api, () => Future.sync(api.dispose));
  }

  Future<void> stopAll() => _stopFuture ??= _stopAll();

  Future<void> _stopAll() async {
    final errors = <({Object error, StackTrace stackTrace})>[];
    final settlements = _startSettlements.values.toList(growable: false);
    await Future.wait(
      settlements.map((settlement) async {
        try {
          await settlement;
        } on PluginStartAbortedException catch (error, stackTrace) {
          if (!_earlyDisposeStarted) {
            errors.add((error: error, stackTrace: stackTrace));
          }
        } on Object catch (error, stackTrace) {
          errors.add((error: error, stackTrace: stackTrace));
        }
      }),
    );

    final startedPlugins = _startedPlugins.values.toList(growable: false);
    await Future.wait(
      startedPlugins.map((started) async {
        try {
          await started.plugin.shutdown(budget: started.shutdownBudget);
        } on Object catch (error, stackTrace) {
          errors.add((error: error, stackTrace: stackTrace));
        }
      }),
    );
    if (errors case [final first, ...]) {
      Error.throwWithStackTrace(first.error, first.stackTrace);
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await stopAll();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    } finally {
      for (final subscription in _statusSubscriptions.values) {
        try {
          await subscription.cancel();
        } on Object catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      try {
        await _metadataSubject?.close();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  void _requireEnabled(String id) {
    final enabledPlugins = _enabledPlugins;
    if (enabledPlugins == null) {
      throw StateError("Plugin selection has not been registered.");
    }
    if (!enabledPlugins.any((plugin) => plugin.id == id)) {
      throw StateError('Plugin "$id" is not enabled.');
    }
  }

  void _publishState({required String id, required PluginLifecycleState state}) {
    final current = _metadataById[id];
    if (current == null) {
      throw StateError('Plugin "$id" is not enabled.');
    }
    _metadataById[id] = current.copyWith(state: state, actionHint: _actionHint(state));
    _metadataSubject!.add(_orderedMetadata());
  }

  List<PluginMetadata> _orderedMetadata() {
    final enabledPlugins = _enabledPlugins;
    if (enabledPlugins == null) {
      throw StateError("Plugin selection has not been registered.");
    }
    return List<PluginMetadata>.unmodifiable(
      enabledPlugins.map((plugin) => _metadataById[plugin.id]!),
    );
  }

  EffectivePluginSelection _resolveSelection({
    required Set<String> disabledPluginIds,
    required List<RegisteredPluginMetadata> registeredPlugins,
    required Map<String, PluginSetupStatus> setupById,
  }) {
    final enabledIds = List<String>.unmodifiable([
      for (final plugin in registeredPlugins)
        if (!disabledPluginIds.contains(plugin.id)) plugin.id,
    ]);
    final readyIds = List<String>.unmodifiable([
      for (final id in enabledIds)
        if (setupById[id] is PluginSetupReady) id,
    ]);
    return (
      enabledPluginIds: enabledIds,
      eagerPluginIds: readyIds,
      defaultPluginId: readyIds.isEmpty ? null : readyIds.first,
    );
  }

  String? _routableDefaultPluginId() {
    final selection = _effectiveSelection;
    if (selection == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    final preferredDefault = selection.defaultPluginId;
    if (preferredDefault != null && _operationalPlugins.containsKey(preferredDefault)) {
      return preferredDefault;
    }
    for (final id in selection.enabledPluginIds) {
      if (_operationalPlugins.containsKey(id)) return id;
    }
    return null;
  }

  PluginSetupMetadata _mapSetupMetadata({
    required RegisteredPluginMetadata plugin,
    required PluginSetupStatus setup,
  }) {
    return PluginSetupMetadata(
      id: plugin.id,
      displayName: plugin.displayName,
      state: switch (setup) {
        PluginSetupNotInspected() => PluginSetupState.notInspected,
        PluginSetupReady() => PluginSetupState.ready,
        PluginSetupRuntimeMissing() => PluginSetupState.runtimeMissing,
        PluginSetupAuthenticationRequired() => PluginSetupState.authenticationRequired,
        PluginSetupUnavailable() => PluginSetupState.unavailable,
        PluginSetupUnknown() => PluginSetupState.unknown,
      },
      actionHint: setup.actionHint,
    );
  }

  static String? _actionHint(PluginLifecycleState state) => switch (state) {
    PluginLifecycleState.unavailable => "Check the bridge console to make this plugin available.",
    PluginLifecycleState.degraded => "Check the bridge console if this plugin needs attention.",
    PluginLifecycleState.failed => "Check the bridge console and restart the bridge to retry this plugin.",
    PluginLifecycleState.ready => null,
  };
}

class _StartedPlugin {
  const _StartedPlugin({required this.plugin, required this.shutdownBudget});

  final BridgePlugin plugin;
  final Duration shutdownBudget;
}
