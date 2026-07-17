import "dart:async";
import "dart:collection";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

typedef PluginCompositionView = ({
  Set<String> knownPluginIds,
  List<String> enabledPluginIds,
  String defaultEnabledPluginId,
  Map<String, BridgePluginApi> operationalPlugins,
});

typedef EnabledPluginRegistration = ({String id, String displayName, bool isDefault});

class PluginLifecycleService {
  PluginLifecycleService();

  final Map<String, BridgePluginApi> _operationalPlugins = <String, BridgePluginApi>{};
  final Map<String, _StartedPlugin> _startedPlugins = <String, _StartedPlugin>{};
  final Map<String, Future<void>> _startSettlements = <String, Future<void>>{};
  final Map<String, StreamSubscription<PluginStatus>> _statusSubscriptions =
      <String, StreamSubscription<PluginStatus>>{};
  final Map<BridgePluginApi, Future<void>> _earlyDisposals = <BridgePluginApi, Future<void>>{};

  Set<String>? _knownPluginIds;
  List<EnabledPluginRegistration>? _enabledPlugins;
  late final Map<String, PluginMetadata> _metadataById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  bool _earlyDisposeStarted = false;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  void registerSelection({
    required Set<String> knownPluginIds,
    required List<EnabledPluginRegistration> enabledPlugins,
  }) {
    if (_knownPluginIds != null) {
      throw StateError("Plugin selection is already registered.");
    }
    if (enabledPlugins.isEmpty) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "must not be empty");
    }
    final enabledIds = enabledPlugins.map((plugin) => plugin.id).toList(growable: false);
    if (enabledIds.toSet().length != enabledIds.length) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "must not contain duplicate ids");
    }
    if (enabledPlugins.where((plugin) => plugin.isDefault).length != 1) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "must contain exactly one default plugin");
    }
    if (!knownPluginIds.containsAll(enabledIds)) {
      throw ArgumentError.value(enabledPlugins, "enabledPlugins", "contains an unknown plugin id");
    }

    _knownPluginIds = Set<String>.unmodifiable(knownPluginIds);
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
      defaultEnabledPluginId: enabledPlugins.singleWhere((plugin) => plugin.isDefault).id,
      operationalPlugins: UnmodifiableMapView<String, BridgePluginApi>(_operationalPlugins),
    );
  }

  List<PluginMetadata> get metadataSnapshot => List<PluginMetadata>.unmodifiable(_orderedMetadata());

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
