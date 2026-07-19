import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/runtime/plugin_runtime.dart";
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
  List<String> eagerPluginIds,
  String? defaultPluginId,
});

class PluginLifecycleService {
  PluginLifecycleService({required PluginLifecycleRepository lifecycleRepository})
    : _lifecycleRepository = lifecycleRepository;

  final PluginLifecycleRepository _lifecycleRepository;
  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  List<String>? _eligiblePluginIds;
  List<String>? _setupReadyPluginIds;
  String? _preferredDefaultPluginId;
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  StreamSubscription<List<PluginLifecycleSnapshot>>? _runtimeSubscription;
  Future<void>? _disposeFuture;

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
    _preferredDefaultPluginId = setupReadyPluginIds.firstOrNull;
    _metadataById = <String, PluginMetadata>{
      for (final plugin in registeredPlugins)
        if (eligiblePluginIds.contains(plugin.id))
          plugin.id: PluginMetadata(
            id: plugin.id,
            displayName: plugin.displayName,
            isDefault: plugin.id == _preferredDefaultPluginId,
            state: PluginLifecycleState.unavailable,
            actionHint: _actionHint(PluginLifecycleState.unavailable),
          ),
    };
    _lifecycleRepository.applyAccess(
      eligiblePluginIds: eligiblePluginIds.toSet(),
      startAllowedPluginIds: setupReadyPluginIds.toSet(),
    );
    _metadataSubject = BehaviorSubject<List<PluginMetadata>>.seeded(_orderedMetadata());
    _runtimeSubscription = _lifecycleRepository.snapshots.listen(_applyRuntimeSnapshots);
    return (
      eligiblePluginIds: eligiblePluginIds,
      eagerPluginIds: setupReadyPluginIds,
      defaultPluginId: _preferredDefaultPluginId,
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

  void _applyRuntimeSnapshots(List<PluginLifecycleSnapshot> snapshots) {
    for (final snapshot in snapshots) {
      final current = _metadataById[snapshot.pluginId];
      if (current == null) continue;
      final state = switch (snapshot.state) {
        PluginRuntimeState.active || PluginRuntimeState.starting => PluginLifecycleState.ready,
        PluginRuntimeState.degraded || PluginRuntimeState.stopping => PluginLifecycleState.degraded,
        PluginRuntimeState.failed => PluginLifecycleState.failed,
        PluginRuntimeState.disabled ||
        PluginRuntimeState.blocked ||
        PluginRuntimeState.dormant => PluginLifecycleState.unavailable,
      };
      _metadataById[snapshot.pluginId] = current.copyWith(state: state, actionHint: _actionHint(state));
    }
    final subject = _metadataSubject;
    if (subject != null && !subject.isClosed) subject.add(_orderedMetadata());
  }

  List<PluginMetadata> _orderedMetadata() {
    final eligiblePluginIds = _requireEligiblePluginIds();
    return List<PluginMetadata>.unmodifiable([
      for (final pluginId in eligiblePluginIds) _metadataById[pluginId]!,
    ]);
  }

  String? _selectableDefaultPluginId() {
    final eligiblePluginIds = _requireEligiblePluginIds();
    final selectableIds = {
      for (final snapshot in _lifecycleRepository.snapshot)
        if (_isSelectable(snapshot)) snapshot.pluginId,
    };
    final preferred = _preferredDefaultPluginId;
    if (preferred != null && selectableIds.contains(preferred)) return preferred;
    for (final pluginId in eligiblePluginIds) {
      if (selectableIds.contains(pluginId)) return pluginId;
    }
    return null;
  }

  bool _isSelectable(PluginLifecycleSnapshot snapshot) {
    if (!snapshot.eligible) return false;
    return switch (snapshot.state) {
      PluginRuntimeState.starting || PluginRuntimeState.active || PluginRuntimeState.degraded => true,
      PluginRuntimeState.disabled ||
      PluginRuntimeState.blocked ||
      PluginRuntimeState.dormant ||
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
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }

  static String? _actionHint(PluginLifecycleState state) => switch (state) {
    PluginLifecycleState.unavailable => "Check the bridge console to make this plugin available.",
    PluginLifecycleState.degraded => "Check the bridge console if this plugin needs attention.",
    PluginLifecycleState.failed => "Check the bridge console and restart the bridge to retry this plugin.",
    PluginLifecycleState.ready => null,
  };
}
