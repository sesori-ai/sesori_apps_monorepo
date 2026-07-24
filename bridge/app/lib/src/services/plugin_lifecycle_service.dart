import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/runtime/plugin_runtime.dart";
import "../repositories/bridge_settings_repository.dart";
import "../repositories/plugin_lifecycle_repository.dart";

typedef PluginCompositionView = ({
  Set<String> knownPluginIds,
  List<String> eligiblePluginIds,
  String? defaultPluginId,
  Map<String, PluginProjectOwnership> projectOwnershipById,
});

typedef RegisteredPluginMetadata = ({String id, String displayName});

typedef PluginStartupPolicy = ({
  List<String> eligiblePluginIds,
  String? defaultPluginId,
});

class PluginIdleTimerScheduler {
  const PluginIdleTimerScheduler();

  Timer schedule({required Duration duration, required void Function() onElapsed}) {
    return Timer(duration, onElapsed);
  }
}

class PluginLifecycleService {
  PluginLifecycleService({
    required PluginLifecycleRepository lifecycleRepository,
    required String preferredDefaultPluginId,
    required BridgeSettingsRepository bridgeSettingsRepository,
    required PluginIdleTimerScheduler idleTimerScheduler,
  }) : _lifecycleRepository = lifecycleRepository,
       _preferredDefaultPluginId = preferredDefaultPluginId,
       _bridgeSettingsRepository = bridgeSettingsRepository,
       _idleTimerScheduler = idleTimerScheduler;

  final PluginLifecycleRepository _lifecycleRepository;
  final String _preferredDefaultPluginId;
  final BridgeSettingsRepository _bridgeSettingsRepository;
  final PluginIdleTimerScheduler _idleTimerScheduler;
  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  List<String>? _eligiblePluginIds;
  List<String>? _setupReadyPluginIds;
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  BehaviorSubject<List<String>>? _readyPluginIdsSubject;
  StreamSubscription<List<PluginLifecycleSnapshot>>? _runtimeSubscription;
  Future<void>? _disposeFuture;
  final Map<String, ({Duration duration, Timer timer})> _idleTimers = {};
  bool _disposing = false;

  void registerPlugins({required List<RegisteredPluginMetadata> plugins}) {
    if (_registeredPlugins != null) throw StateError("Plugins are already registered.");
    final ids = plugins.map((plugin) => plugin.id).toList(growable: false);
    if (ids.toSet().length != ids.length) {
      throw ArgumentError.value(plugins, "plugins", "must not contain duplicate ids");
    }
    final sorted = [...plugins]
      ..sort((left, right) {
        final byName = left.displayName.toLowerCase().compareTo(right.displayName.toLowerCase());
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
    _registeredPlugins = List<RegisteredPluginMetadata>.unmodifiable(sorted);
    _knownPluginIds = Set<String>.unmodifiable(ids);
  }

  PluginStartupPolicy initialize({
    required Set<String> disabledPluginIds,
    required Map<String, PluginSetupStatus> setupById,
  }) {
    if (_eligiblePluginIds != null) throw StateError("Plugin lifecycle is already initialized.");
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
    final eligiblePluginIds = List<String>.unmodifiable([
      for (final plugin in registeredPlugins)
        if (!disabledPluginIds.contains(plugin.id)) plugin.id,
    ]);
    final setupReadyPluginIds = List<String>.unmodifiable([
      for (final pluginId in eligiblePluginIds)
        if (setupById[pluginId] is PluginSetupReady) pluginId,
    ]);
    _eligiblePluginIds = eligiblePluginIds;
    _setupReadyPluginIds = setupReadyPluginIds;
    final defaultPluginId = _defaultPluginIdFrom(candidateIds: setupReadyPluginIds.toSet());
    _metadataById = <String, PluginMetadata>{
      for (final plugin in registeredPlugins)
        if (eligiblePluginIds.contains(plugin.id))
          plugin.id: PluginMetadata(
            id: plugin.id,
            displayName: plugin.displayName,
            isDefault: plugin.id == defaultPluginId,
            state: setupById[plugin.id] is PluginSetupReady
                ? PluginLifecycleState.ready
                : PluginLifecycleState.unavailable,
            actionHint: setupById[plugin.id] is PluginSetupReady
                ? _actionHint(PluginLifecycleState.ready)
                : _actionHint(PluginLifecycleState.unavailable),
          ),
    };
    _lifecycleRepository.applyAccess(
      eligiblePluginIds: eligiblePluginIds.toSet(),
      startAllowedPluginIds: setupReadyPluginIds.toSet(),
    );
    _metadataSubject = BehaviorSubject<List<PluginMetadata>>.seeded(_orderedMetadata());
    _readyPluginIdsSubject = BehaviorSubject<List<String>>.seeded(
      _buildReadyPluginIds(_lifecycleRepository.snapshot),
    );
    _runtimeSubscription = _lifecycleRepository.snapshots.listen(_applyRuntimeSnapshots);
    return (
      eligiblePluginIds: eligiblePluginIds,
      defaultPluginId: defaultPluginId,
    );
  }

  void applyAvailability({required Set<String> availablePluginIds}) {
    final eligiblePluginIds = _requireEligiblePluginIds();
    final setupReadyPluginIds = _setupReadyPluginIds;
    if (setupReadyPluginIds == null) throw StateError("Plugin lifecycle has not been initialized.");
    _lifecycleRepository.applyAccess(
      eligiblePluginIds: eligiblePluginIds.toSet(),
      startAllowedPluginIds: setupReadyPluginIds.where(availablePluginIds.contains).toSet(),
    );
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
  }

  PluginCompositionView get compositionView {
    final knownPluginIds = _knownPluginIds;
    final eligiblePluginIds = _requireEligiblePluginIds();
    if (knownPluginIds == null) throw StateError("Plugin lifecycle has not been initialized.");
    return (
      knownPluginIds: knownPluginIds,
      eligiblePluginIds: eligiblePluginIds,
      defaultPluginId: _selectableDefaultPluginId(),
      projectOwnershipById: Map<String, PluginProjectOwnership>.unmodifiable({
        for (final snapshot in _lifecycleRepository.snapshot) snapshot.pluginId: snapshot.projectOwnership,
      }),
    );
  }

  List<PluginMetadata> get metadataSnapshot => List<PluginMetadata>.unmodifiable(_orderedMetadata());

  List<PluginMetadata> get selectableMetadataSnapshot {
    final selectableIds = {
      for (final snapshot in _lifecycleRepository.snapshot)
        if (_isSelectable(snapshot)) snapshot.pluginId,
    };
    final defaultId = _selectableDefaultPluginId();
    return List<PluginMetadata>.unmodifiable([
      for (final metadata in _orderedMetadata())
        if (selectableIds.contains(metadata.id)) metadata.copyWith(isDefault: metadata.id == defaultId),
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
    if (subject == null) throw StateError("Plugin lifecycle has not been initialized.");
    return subject.stream;
  }

  Stream<List<String>> get readyPluginIds {
    final subject = _readyPluginIdsSubject;
    if (subject == null) throw StateError("Plugin lifecycle has not been initialized.");
    return subject.stream;
  }

  void _applyRuntimeSnapshots(List<PluginLifecycleSnapshot> snapshots) {
    final setupById = _setupById;
    if (setupById != null) {
      _setupById = Map<String, PluginSetupStatus>.unmodifiable({
        ...setupById,
        for (final snapshot in snapshots) snapshot.pluginId: snapshot.setup,
      });
    }
    for (final snapshot in snapshots) {
      final current = _metadataById[snapshot.pluginId];
      if (current == null) continue;
      final state = switch (snapshot.state) {
        PluginRuntimeState.dormant ||
        PluginRuntimeState.active ||
        PluginRuntimeState.starting => PluginLifecycleState.ready,
        PluginRuntimeState.degraded || PluginRuntimeState.stopping => PluginLifecycleState.degraded,
        PluginRuntimeState.failed => PluginLifecycleState.failed,
        PluginRuntimeState.disabled || PluginRuntimeState.blocked => PluginLifecycleState.unavailable,
      };
      _metadataById[snapshot.pluginId] = current.copyWith(state: state, actionHint: _actionHint(state));
    }
    final subject = _metadataSubject;
    if (subject != null && !subject.isClosed) subject.add(_orderedMetadata());
    _publishReadyPluginIds(snapshots);
    _syncIdleTimers(snapshots);
  }

  List<PluginMetadata> _orderedMetadata() {
    final eligiblePluginIds = _requireEligiblePluginIds();
    return List<PluginMetadata>.unmodifiable([
      for (final pluginId in eligiblePluginIds) _metadataById[pluginId]!,
    ]);
  }

  String? _selectableDefaultPluginId() {
    final selectableIds = {
      for (final snapshot in _lifecycleRepository.snapshot)
        if (_isSelectable(snapshot)) snapshot.pluginId,
    };
    return _defaultPluginIdFrom(candidateIds: selectableIds);
  }

  String? _defaultPluginIdFrom({required Set<String> candidateIds}) {
    if (candidateIds.contains(_preferredDefaultPluginId)) return _preferredDefaultPluginId;
    final eligiblePluginIds = _requireEligiblePluginIds();
    for (final pluginId in eligiblePluginIds) {
      if (candidateIds.contains(pluginId)) return pluginId;
    }
    return null;
  }

  bool _isSelectable(PluginLifecycleSnapshot snapshot) {
    if (!snapshot.eligible) return false;
    return switch (snapshot.state) {
      PluginRuntimeState.dormant ||
      PluginRuntimeState.starting ||
      PluginRuntimeState.active ||
      PluginRuntimeState.degraded => true,
      PluginRuntimeState.disabled ||
      PluginRuntimeState.blocked ||
      PluginRuntimeState.stopping ||
      PluginRuntimeState.failed => false,
    };
  }

  List<String> _requireEligiblePluginIds() {
    final eligiblePluginIds = _eligiblePluginIds;
    if (eligiblePluginIds == null) throw StateError("Plugin lifecycle has not been initialized.");
    return eligiblePluginIds;
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

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposing = true;
    for (final entry in _idleTimers.values) {
      entry.timer.cancel();
    }
    _idleTimers.clear();
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _runtimeSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    try {
      await _metadataSubject?.close();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    try {
      await _readyPluginIdsSubject?.close();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  List<String> _buildReadyPluginIds(List<PluginLifecycleSnapshot> snapshots) {
    final byId = <String, PluginLifecycleSnapshot>{
      for (final snapshot in snapshots) snapshot.pluginId: snapshot,
    };
    return List<String>.unmodifiable([
      for (final pluginId in _requireEligiblePluginIds())
        if (byId[pluginId] case final snapshot?)
          if (snapshot.eligible && snapshot.startAllowed && snapshot.setup is PluginSetupReady) pluginId,
    ]);
  }

  void _publishReadyPluginIds(List<PluginLifecycleSnapshot> snapshots) {
    final subject = _readyPluginIdsSubject;
    if (subject == null || subject.isClosed) return;
    final next = _buildReadyPluginIds(snapshots);
    final current = subject.value;
    if (current.length == next.length) {
      var equal = true;
      for (var index = 0; index < current.length; index++) {
        if (current[index] != next[index]) {
          equal = false;
          break;
        }
      }
      if (equal) return;
    }
    subject.add(next);
  }

  void _syncIdleTimers(List<PluginLifecycleSnapshot> snapshots) {
    if (_disposing) return;
    final currentIds = snapshots.map((snapshot) => snapshot.pluginId).toSet();
    _idleTimers.keys.where((pluginId) => !currentIds.contains(pluginId)).toList().forEach(_cancelIdleTimer);
    for (final snapshot in snapshots) {
      final timeoutMins = _effectiveIdleTimeoutMins(snapshot.pluginId);
      if (timeoutMins <= 0 || !_isIdleCandidate(snapshot)) {
        _cancelIdleTimer(snapshot.pluginId);
        continue;
      }
      final duration = Duration(minutes: timeoutMins);
      final existing = _idleTimers[snapshot.pluginId];
      if (existing != null && existing.duration == duration) continue;
      _cancelIdleTimer(snapshot.pluginId);
      late final Timer timer;
      timer = _idleTimerScheduler.schedule(
        duration: duration,
        onElapsed: () => unawaited(
          _stopAfterIdleWindow(
            pluginId: snapshot.pluginId,
            timer: timer,
          ),
        ),
      );
      _idleTimers[snapshot.pluginId] = (duration: duration, timer: timer);
    }
  }

  void _cancelIdleTimer(String pluginId) {
    _idleTimers.remove(pluginId)?.timer.cancel();
  }

  bool _isIdleCandidate(PluginLifecycleSnapshot snapshot) {
    return snapshot.eligible &&
        snapshot.workState == PluginWorkState.idle &&
        snapshot.leaseCount == 0 &&
        snapshot.transitionSettled &&
        (snapshot.state == PluginRuntimeState.active || snapshot.state == PluginRuntimeState.degraded);
  }

  int _effectiveIdleTimeoutMins(String pluginId) {
    return _bridgeSettingsRepository.currentSettings.plugins.idleTimeoutMinsFor(pluginId: pluginId);
  }

  Future<void> _stopAfterIdleWindow({
    required String pluginId,
    required Timer timer,
  }) async {
    if (_disposing || !identical(_idleTimers[pluginId]?.timer, timer)) return;
    _idleTimers.remove(pluginId);
    final snapshot = _lifecycleRepository.snapshot.where((entry) => entry.pluginId == pluginId).firstOrNull;
    if (snapshot == null || _effectiveIdleTimeoutMins(pluginId) <= 0 || !_isIdleCandidate(snapshot)) return;
    try {
      await _lifecycleRepository.stopSafely(pluginId: pluginId);
    } on Object catch (error, stackTrace) {
      Log.w('Idle suspension failed for plugin "$pluginId"', error, stackTrace);
    }
    _syncIdleTimers(_lifecycleRepository.snapshot);
  }

  static String? _actionHint(PluginLifecycleState state) => switch (state) {
    PluginLifecycleState.unavailable => "Check the bridge console to make this plugin available.",
    PluginLifecycleState.degraded => "Check the bridge console if this plugin needs attention.",
    PluginLifecycleState.failed => "Check the bridge console and restart the bridge to retry this plugin.",
    PluginLifecycleState.ready => null,
  };
}
