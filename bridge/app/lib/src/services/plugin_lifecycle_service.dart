import "dart:async";
import "dart:convert";
import "dart:math";

import "package:collection/collection.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PluginRuntimeState;
import "package:sesori_shared/sesori_shared.dart" as shared show PluginRuntimeState;

import "../auth/bridge_id_provider.dart";
import "../bridge/runtime/plugin_runtime.dart";
import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";
import "../repositories/plugin_lifecycle_repository.dart";

typedef PluginCompositionView = ({
  Set<String> knownPluginIds,
  List<String> orderedPluginIds,
  List<String> eligiblePluginIds,
  String? defaultPluginId,
  Map<String, PluginProjectOwnership> projectOwnershipById,
});

typedef RegisteredPluginMetadata = ({String id, String displayName, PluginResidencyPolicy residencyPolicy});

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
    required BridgeIdProvider bridgeIdProvider,
  }) : _lifecycleRepository = lifecycleRepository,
       _preferredDefaultPluginId = preferredDefaultPluginId,
       _bridgeSettingsRepository = bridgeSettingsRepository,
       _idleTimerScheduler = idleTimerScheduler,
       _bridgeIdProvider = bridgeIdProvider;

  final PluginLifecycleRepository _lifecycleRepository;
  final String _preferredDefaultPluginId;
  final BridgeSettingsRepository _bridgeSettingsRepository;
  final PluginIdleTimerScheduler _idleTimerScheduler;
  final BridgeIdProvider _bridgeIdProvider;
  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  Map<String, PluginResidencyPolicy>? _residencyPolicyById;
  List<String>? _eligiblePluginIds;
  Set<String> _startAllowedPluginIds = {};
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  BehaviorSubject<List<String>>? _readyPluginIdsSubject;
  final StreamController<String> _managementSnapshotTokenController = StreamController<String>.broadcast(sync: true);
  StreamSubscription<List<PluginLifecycleSnapshot>>? _runtimeSubscription;
  Future<void>? _disposeFuture;
  Future<void> _settingsMutationTail = Future<void>.value();
  final Map<String, _ActivePluginCommand> _activePluginCommands = {};
  final Set<String> _deferredReadyPluginIds = {};
  final Map<String, ({Duration duration, Timer timer})> _idleTimers = {};
  _PluginManagementSnapshot? _lastPublishedManagementSnapshot;
  final Random _random = Random.secure();
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
    _residencyPolicyById = Map<String, PluginResidencyPolicy>.unmodifiable({
      for (final plugin in plugins) plugin.id: plugin.residencyPolicy,
    });
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
    final setupReadyPluginIds = <String>{
      for (final pluginId in eligiblePluginIds)
        if (setupById[pluginId] is PluginSetupReady) pluginId,
    };
    _eligiblePluginIds = eligiblePluginIds;
    _startAllowedPluginIds = setupReadyPluginIds;
    _applyAccess();
    _rebuildMetadata();
    final defaultPluginId = _selectableDefaultPluginId();
    _metadataSubject = BehaviorSubject<List<PluginMetadata>>.seeded(_orderedMetadata());
    _readyPluginIdsSubject = BehaviorSubject<List<String>>.seeded(
      _buildReadyPluginIds(_lifecycleRepository.snapshot),
    );
    if (_hasCompleteManagementRuntimeSnapshot) {
      _lastPublishedManagementSnapshot = _buildManagementSnapshot(snapshotToken: _newManagementSnapshotToken());
    }
    _runtimeSubscription = _lifecycleRepository.snapshots.listen(_applyRuntimeSnapshots);
    return (
      eligiblePluginIds: eligiblePluginIds,
      defaultPluginId: defaultPluginId,
    );
  }

  void applyAvailability({required Set<String> availablePluginIds}) {
    final eligiblePluginIds = _requireEligiblePluginIds();
    final setupById = _requireSetupById();
    _startAllowedPluginIds = {
      for (final pluginId in eligiblePluginIds)
        if (availablePluginIds.contains(pluginId) && setupById[pluginId] is PluginSetupReady) pluginId,
    };
    _applyAccess();
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
  }

  PluginCompositionView get compositionView {
    final knownPluginIds = _knownPluginIds;
    final eligiblePluginIds = _requireEligiblePluginIds();
    if (knownPluginIds == null) throw StateError("Plugin lifecycle has not been initialized.");
    return (
      knownPluginIds: knownPluginIds,
      orderedPluginIds: List<String>.unmodifiable(_registeredPlugins!.map((plugin) => plugin.id)),
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

  PluginManagementResponse get managementSnapshot {
    if (_registeredPlugins == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    final snapshot = _lastPublishedManagementSnapshot;
    if (snapshot == null) throw StateError("Plugin management snapshot is not ready.");
    final bridgeId = _requireBridgeId();
    return PluginManagementResponse(
      snapshotToken: snapshot.snapshotToken,
      bridgeId: bridgeId,
      defaultPluginId: snapshot.defaultPluginId,
      defaultIdleTimeoutMins: snapshot.defaultIdleTimeoutMins,
      plugins: snapshot.plugins,
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

  Stream<String> get managementSnapshotTokens => _managementSnapshotTokenController.stream;

  Future<PluginManagementResponse> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    final knownPluginIds = _knownPluginIds;
    if (knownPluginIds == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    if (!knownPluginIds.contains(pluginId)) {
      throw PluginManagementPluginNotFoundException(pluginId);
    }
    if (_lastPublishedManagementSnapshot == null) {
      throw StateError("Plugin management snapshot is not ready.");
    }
    _requireBridgeId();
    final active = _activePluginCommands[pluginId];
    if (active != null) {
      if (active.request == request) return active.completer.future;
      throw PluginManagementConflictException(
        PluginLifecycleConflict(
          pluginId: pluginId,
          reasons: const [PluginLifecycleConflictReason.transitioning],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }

    final command = _ActivePluginCommand(request: request);
    _activePluginCommands[pluginId] = command;
    unawaited(_executeCommand(pluginId: pluginId, command: command));
    return command.completer.future;
  }

  Future<PluginManagementResponse> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) {
    final knownPluginIds = _knownPluginIds;
    if (knownPluginIds == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    if (_lastPublishedManagementSnapshot == null) {
      throw StateError("Plugin management snapshot is not ready.");
    }
    switch (request) {
      case PluginIdleTimeoutApplyAllRequest():
        break;
      case PluginIdleTimeoutSetOverrideRequest(:final pluginId) ||
          PluginIdleTimeoutClearOverrideRequest(:final pluginId):
        if (!knownPluginIds.contains(pluginId)) {
          throw PluginManagementPluginNotFoundException(pluginId);
        }
    }
    _requireBridgeId();
    return _withSettingsMutationTail(() async {
      _requireBridgeId();
      final current = await _bridgeSettingsRepository.loadSettings();
      final plugins = switch (request) {
        PluginIdleTimeoutApplyAllRequest(:final idleTimeoutMins) => current.plugins.withDefaultIdleTimeout(
          idleTimeoutMins: idleTimeoutMins,
          clearOverridePluginIds: knownPluginIds,
        ),
        PluginIdleTimeoutSetOverrideRequest(:final pluginId, :final idleTimeoutMins) =>
          current.plugins.withPluginIdleTimeout(pluginId: pluginId, idleTimeoutMins: idleTimeoutMins),
        PluginIdleTimeoutClearOverrideRequest(:final pluginId) => current.plugins.withPluginIdleTimeout(
          pluginId: pluginId,
          idleTimeoutMins: null,
        ),
      };
      _requireBridgeId();
      await _bridgeSettingsRepository.saveSettings(settings: current.copyWith(plugins: plugins));
      _syncIdleTimers(_lifecycleRepository.snapshot);
      _publishManagementIfChanged();
      return managementSnapshot;
    });
  }

  Future<T> _withSettingsMutationTail<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _settingsMutationTail = _settingsMutationTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _executeCommand({
    required String pluginId,
    required _ActivePluginCommand command,
  }) async {
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      switch (command.request) {
        case PluginLifecycleEnableRequest():
          await _enable(pluginId: pluginId, command: command);
        case PluginLifecycleDisableRequest(:final mode):
          await _disable(pluginId: pluginId, mode: mode);
        case PluginLifecycleRestartRequest(:final mode):
          await _restart(pluginId: pluginId, mode: mode, command: command);
        case PluginLifecycleRefreshRequest():
          await _refresh(pluginId: pluginId, command: command);
      }
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    }

    if (identical(_activePluginCommands[pluginId], command)) {
      _activePluginCommands.remove(pluginId);
    }
    _publishManagementIfChanged();
    if (failure == null) {
      try {
        command.completer.complete(managementSnapshot);
      } on Object catch (error, stackTrace) {
        command.completer.completeError(error, stackTrace);
      }
    } else {
      command.completer.completeError(failure, failureStackTrace);
    }
  }

  String _requireBridgeId() {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null) throw StateError("Bridge identity is not registered.");
    return bridgeId;
  }

  Future<void> _enable({required String pluginId, required _ActivePluginCommand command}) async {
    if (!_requireEligiblePluginIds().contains(pluginId)) {
      await _persistPluginDisabled(pluginId: pluginId, disabled: false);
      _setEligibility(pluginId: pluginId, eligible: true);
    }
    if (!_isPublishedReady(pluginId: pluginId)) _deferredReadyPluginIds.add(pluginId);
    final setup = await _inspectForCommand(pluginId: pluginId, command: command);
    if (setup is! PluginSetupReady) {
      _deferredReadyPluginIds.remove(pluginId);
      return;
    }
    _handleRuntimeCommandResult(
      pluginId: pluginId,
      result: await _lifecycleRepository.start(pluginId: pluginId),
    );
    _publishDeferredReadyPlugin(pluginId: pluginId);
  }

  Future<void> _disable({required String pluginId, required PluginStopMode mode}) async {
    if (!_requireEligiblePluginIds().contains(pluginId)) return;
    final result = await _lifecycleRepository.prepareDisable(
      pluginId: pluginId,
      intent: switch (mode) {
        PluginStopMode.safe => PluginStopIntent.safe,
        PluginStopMode.force => PluginStopIntent.force,
      },
    );
    switch (result) {
      case PluginRuntimeCommandConflict(:final reasons):
        throw PluginManagementConflictException(
          PluginLifecycleConflict(
            pluginId: pluginId,
            reasons: reasons.map(_mapConflictReason).toList(growable: false),
            current: _managementRowForPluginId(pluginId),
          ),
        );
      case PluginRuntimeCommandFailed(:final message):
        throw PluginManagementCommandFailedException(message);
      case PluginRuntimeCommandApplied() || PluginRuntimeCommandCurrent():
        break;
    }

    try {
      await _persistPluginDisabled(pluginId: pluginId, disabled: true);
    } on Object catch (error) {
      try {
        _lifecycleRepository.rollbackDisable(pluginId: pluginId);
      } on Object catch (rollbackError) {
        throw PluginManagementCommandFailedException(
          "Plugin disable persistence failed ($error) and runtime rollback failed ($rollbackError).",
        );
      }
      _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
      throw PluginManagementCommandFailedException("Plugin disable persistence failed: $error");
    }

    try {
      _lifecycleRepository.commitDisable(pluginId: pluginId);
    } on Object catch (error) {
      _setEligibility(pluginId: pluginId, eligible: false);
      throw PluginManagementCommandFailedException("Plugin disable commit failed: $error");
    }
    _setEligibility(pluginId: pluginId, eligible: false);
  }

  Future<void> _restart({
    required String pluginId,
    required PluginStopMode mode,
    required _ActivePluginCommand command,
  }) async {
    if (!_requireEligiblePluginIds().contains(pluginId)) {
      throw PluginManagementConflictException(
        PluginLifecycleConflict(
          pluginId: pluginId,
          reasons: const [PluginLifecycleConflictReason.notEnabled],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }
    if (!_isPublishedReady(pluginId: pluginId)) _deferredReadyPluginIds.add(pluginId);
    final setup = await _inspectForCommand(pluginId: pluginId, command: command);
    if (setup is! PluginSetupReady) {
      _deferredReadyPluginIds.remove(pluginId);
      return;
    }
    _handleRuntimeCommandResult(
      pluginId: pluginId,
      result: await _lifecycleRepository.restart(
        pluginId: pluginId,
        intent: _mapStopIntent(mode: mode),
      ),
    );
    _publishDeferredReadyPlugin(pluginId: pluginId);
  }

  Future<void> _refresh({required String pluginId, required _ActivePluginCommand command}) async {
    await _inspectForCommand(pluginId: pluginId, command: command);
  }

  Future<PluginSetupStatus> _inspectForCommand({
    required String pluginId,
    required _ActivePluginCommand command,
  }) async {
    final inspected = await _lifecycleRepository.inspect(
      pluginIds: {pluginId},
      markUnselectedNotInspected: false,
    );
    if (!identical(_activePluginCommands[pluginId], command)) {
      throw const PluginManagementCommandFailedException("plugin command was superseded");
    }
    final setup = inspected[pluginId];
    if (setup == null) {
      throw PluginManagementCommandFailedException('Plugin "$pluginId" inspection returned no result.');
    }
    _setupById = Map<String, PluginSetupStatus>.unmodifiable({..._requireSetupById(), pluginId: setup});
    if (_requireEligiblePluginIds().contains(pluginId) && setup is PluginSetupReady) {
      _startAllowedPluginIds.add(pluginId);
    } else {
      _startAllowedPluginIds.remove(pluginId);
    }
    _applyAccess();
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
    return setup;
  }

  Future<void> _persistPluginDisabled({required String pluginId, required bool disabled}) {
    return _withSettingsMutationTail(() async {
      final current = await _bridgeSettingsRepository.loadSettings();
      if (current.plugins.isDisabled(pluginId: pluginId) == disabled) return;
      await _bridgeSettingsRepository.saveSettings(
        settings: current.copyWith(
          plugins: current.plugins.withPluginDisabled(pluginId: pluginId, disabled: disabled),
        ),
      );
    });
  }

  void _handleRuntimeCommandResult({
    required String pluginId,
    required PluginRuntimeCommandResult result,
  }) {
    switch (result) {
      case PluginRuntimeCommandApplied() || PluginRuntimeCommandCurrent():
        return;
      case PluginRuntimeCommandConflict(:final reasons):
        throw PluginManagementConflictException(
          PluginLifecycleConflict(
            pluginId: pluginId,
            reasons: reasons.map(_mapConflictReason).toList(growable: false),
            current: _managementRowForPluginId(pluginId),
          ),
        );
      case PluginRuntimeCommandFailed(:final message):
        throw PluginManagementCommandFailedException(message);
    }
  }

  PluginStopIntent _mapStopIntent({required PluginStopMode mode}) => switch (mode) {
    PluginStopMode.safe => PluginStopIntent.safe,
    PluginStopMode.force => PluginStopIntent.force,
  };

  void _setEligibility({required String pluginId, required bool eligible}) {
    final eligibleIds = _requireEligiblePluginIds().toSet();
    if (eligible) {
      eligibleIds.add(pluginId);
    } else {
      eligibleIds.remove(pluginId);
      _startAllowedPluginIds.remove(pluginId);
    }
    _eligiblePluginIds = List<String>.unmodifiable([
      for (final plugin in _registeredPlugins!)
        if (eligibleIds.contains(plugin.id)) plugin.id,
    ]);
    _rebuildMetadata();
    _applyAccess();
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
  }

  void _applyAccess() {
    _lifecycleRepository.applyAccess(
      eligiblePluginIds: _requireEligiblePluginIds().toSet(),
      startAllowedPluginIds: _startAllowedPluginIds,
    );
  }

  PluginLifecycleConflictReason _mapConflictReason(PluginRuntimeConflictReason reason) => switch (reason) {
    PluginRuntimeConflictReason.inFlight => PluginLifecycleConflictReason.inFlight,
    PluginRuntimeConflictReason.busy => PluginLifecycleConflictReason.busy,
    PluginRuntimeConflictReason.workStateUnknown => PluginLifecycleConflictReason.workStateUnknown,
    PluginRuntimeConflictReason.transitioning => PluginLifecycleConflictReason.transitioning,
    PluginRuntimeConflictReason.notEligible => PluginLifecycleConflictReason.notEnabled,
  };

  void _applyRuntimeSnapshots(List<PluginLifecycleSnapshot> snapshots) {
    final setupById = _setupById;
    if (setupById != null) {
      _setupById = Map<String, PluginSetupStatus>.unmodifiable({
        ...setupById,
        for (final snapshot in snapshots) snapshot.pluginId: snapshot.setup,
      });
    }
    _startAllowedPluginIds = {
      for (final snapshot in snapshots)
        if (snapshot.accessGate != PluginRuntimeAccessGate.disabled && snapshot.startAllowed) snapshot.pluginId,
    };
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
    _publishManagementIfChanged();
  }

  void _rebuildMetadata() {
    final snapshots = {for (final snapshot in _lifecycleRepository.snapshot) snapshot.pluginId: snapshot};
    final setupById = _requireSetupById();
    _metadataById = <String, PluginMetadata>{
      for (final plugin in _registeredPlugins!)
        if (_requireEligiblePluginIds().contains(plugin.id))
          plugin.id: () {
            final runtimeState = snapshots[plugin.id]?.state;
            final state = switch (runtimeState) {
              PluginRuntimeState.dormant ||
              PluginRuntimeState.starting ||
              PluginRuntimeState.active => PluginLifecycleState.ready,
              PluginRuntimeState.degraded || PluginRuntimeState.stopping => PluginLifecycleState.degraded,
              PluginRuntimeState.failed => PluginLifecycleState.failed,
              PluginRuntimeState.disabled || PluginRuntimeState.blocked || null =>
                setupById[plugin.id] is PluginSetupReady
                    ? PluginLifecycleState.ready
                    : PluginLifecycleState.unavailable,
            };
            return PluginMetadata(
              id: plugin.id,
              displayName: plugin.displayName,
              isDefault: false,
              state: state,
              actionHint: _actionHint(state),
            );
          }(),
    };
  }

  List<PluginMetadata> _orderedMetadata() {
    final eligiblePluginIds = _requireEligiblePluginIds();
    final defaultPluginId = _selectableDefaultPluginId();
    return List<PluginMetadata>.unmodifiable([
      for (final pluginId in eligiblePluginIds)
        _metadataById[pluginId]!.copyWith(isDefault: pluginId == defaultPluginId),
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
    if (snapshot.accessGate != PluginRuntimeAccessGate.enabled) return false;
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

  Map<String, PluginSetupStatus> _requireSetupById() {
    final setupById = _setupById;
    if (setupById == null) throw StateError("Plugin lifecycle has not been initialized.");
    return setupById;
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

  PluginManagementMetadata _managementRow({required RegisteredPluginMetadata plugin}) {
    final snapshot = _lifecycleRepository.snapshot.singleWhere((entry) => entry.pluginId == plugin.id);
    final setup = _mapSetupMetadata(plugin: plugin, setup: _setupById![plugin.id]!);
    final settings = _bridgeSettingsRepository.currentSettings;
    return PluginManagementMetadata(
      setup: setup,
      runtimeState: _mapRuntimeState(snapshot.state),
      workState: _mapWorkState(snapshot.workState),
      idleTimeoutMins: _effectiveIdleTimeoutMins(plugin.id),
      hasIdleTimeoutOverride: settings.plugins.settingsByPluginId[plugin.id]?.idleTimeoutMins != null,
      actionHint: setup.actionHint ?? _managementActionHint(snapshot.state),
    );
  }

  PluginManagementMetadata _managementRowForPluginId(String pluginId) {
    final plugin = _registeredPlugins!.singleWhere((candidate) => candidate.id == pluginId);
    return _managementRow(plugin: plugin);
  }

  _PluginManagementSnapshot _buildManagementSnapshot({required String? snapshotToken}) {
    final registeredPlugins = _registeredPlugins;
    if (registeredPlugins == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    final settings = _bridgeSettingsRepository.currentSettings;
    return _PluginManagementSnapshot(
      snapshotToken: snapshotToken,
      defaultPluginId: _selectableDefaultPluginId(),
      defaultIdleTimeoutMins: settings.plugins.defaults.idleTimeoutMins ?? defaultPluginIdleTimeoutMins,
      plugins: [for (final plugin in registeredPlugins) _managementRow(plugin: plugin)],
    );
  }

  void _publishManagementIfChanged() {
    if (_managementSnapshotTokenController.isClosed || !_hasCompleteManagementRuntimeSnapshot) return;
    final previous = _lastPublishedManagementSnapshot;
    if (previous == null) {
      _lastPublishedManagementSnapshot = _buildManagementSnapshot(snapshotToken: _newManagementSnapshotToken());
      return;
    }
    final next = _buildManagementSnapshot(snapshotToken: previous.snapshotToken);
    if (previous == next) return;
    final snapshotToken = _newManagementSnapshotToken();
    _lastPublishedManagementSnapshot = next.withSnapshotToken(snapshotToken: snapshotToken);
    _managementSnapshotTokenController.add(snapshotToken);
  }

  String _newManagementSnapshotToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
    return base64Url.encode(bytes).replaceAll("=", "");
  }

  bool get _hasCompleteManagementRuntimeSnapshot {
    final registeredPlugins = _registeredPlugins;
    if (registeredPlugins == null) return false;
    final runtimePluginIds = _lifecycleRepository.snapshot.map((snapshot) => snapshot.pluginId).toSet();
    return registeredPlugins.every((plugin) => runtimePluginIds.contains(plugin.id));
  }

  shared.PluginRuntimeState _mapRuntimeState(PluginRuntimeState state) => switch (state) {
    PluginRuntimeState.disabled => shared.PluginRuntimeState.disabled,
    PluginRuntimeState.blocked => shared.PluginRuntimeState.blocked,
    PluginRuntimeState.dormant => shared.PluginRuntimeState.dormant,
    PluginRuntimeState.starting => shared.PluginRuntimeState.starting,
    PluginRuntimeState.active => shared.PluginRuntimeState.active,
    PluginRuntimeState.degraded => shared.PluginRuntimeState.degraded,
    PluginRuntimeState.stopping => shared.PluginRuntimeState.stopping,
    PluginRuntimeState.failed => shared.PluginRuntimeState.failed,
  };

  PluginManagementWorkState _mapWorkState(PluginWorkState state) => switch (state) {
    PluginWorkState.idle => PluginManagementWorkState.idle,
    PluginWorkState.busy => PluginManagementWorkState.busy,
    PluginWorkState.unknown => PluginManagementWorkState.unknown,
  };

  String? _managementActionHint(PluginRuntimeState state) => switch (state) {
    PluginRuntimeState.failed => "Check the bridge console and restart the bridge to retry this plugin.",
    PluginRuntimeState.degraded => "Check the bridge console if this plugin needs attention.",
    PluginRuntimeState.blocked => "Check the bridge console to make this plugin available.",
    PluginRuntimeState.disabled ||
    PluginRuntimeState.dormant ||
    PluginRuntimeState.starting ||
    PluginRuntimeState.active ||
    PluginRuntimeState.stopping => null,
  };

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
    try {
      await _managementSnapshotTokenController.close();
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
        if (!_deferredReadyPluginIds.contains(pluginId))
          if (byId[pluginId] case final snapshot?)
            if (snapshot.accessGate == PluginRuntimeAccessGate.enabled &&
                snapshot.startAllowed &&
                snapshot.setup is PluginSetupReady)
              pluginId,
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

  bool _isPublishedReady({required String pluginId}) => _readyPluginIdsSubject?.value.contains(pluginId) ?? false;

  void _publishDeferredReadyPlugin({required String pluginId}) {
    if (!_deferredReadyPluginIds.remove(pluginId)) return;
    _publishReadyPluginIds(_lifecycleRepository.snapshot);
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
    return snapshot.accessGate == PluginRuntimeAccessGate.enabled &&
        snapshot.workState == PluginWorkState.idle &&
        snapshot.leaseCount == 0 &&
        snapshot.transitionSettled &&
        (snapshot.state == PluginRuntimeState.active || snapshot.state == PluginRuntimeState.degraded);
  }

  int _effectiveIdleTimeoutMins(String pluginId) {
    final residencyPolicy = _residencyPolicyById?[pluginId];
    if (residencyPolicy == null) throw StateError("Plugin lifecycle has not been registered.");
    if (residencyPolicy == PluginResidencyPolicy.resident) return 0;
    return _bridgeSettingsRepository.currentSettings.plugins.idleTimeoutMinsFor(pluginId: pluginId);
  }

  Future<void> _stopAfterIdleWindow({
    required String pluginId,
    required Timer timer,
  }) async {
    if (_disposing || !identical(_idleTimers[pluginId]?.timer, timer)) return;
    _idleTimers.remove(pluginId);
    final snapshot = _lifecycleRepository.snapshot.where((entry) => entry.pluginId == pluginId).firstOrNull;
    final timeoutMins = _effectiveIdleTimeoutMins(pluginId);
    if (snapshot == null || timeoutMins <= 0 || !_isIdleCandidate(snapshot)) return;
    Log.d('Plugin "$pluginId" idle timeout elapsed (${timeoutMins}m); requesting safe suspension');
    try {
      final result = await _lifecycleRepository.stopSafely(pluginId: pluginId);
      switch (result) {
        case PluginRuntimeCommandApplied():
          break;
        case PluginRuntimeCommandCurrent():
          Log.d('Idle suspension for plugin "$pluginId" was already current');
        case PluginRuntimeCommandConflict(:final reasons):
          Log.d(
            'Idle suspension deferred for plugin "$pluginId" (${reasons.map((reason) => reason.name).join(", ")})',
          );
        case PluginRuntimeCommandFailed(:final message):
          Log.w('Idle suspension failed for plugin "$pluginId": $message');
      }
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

@immutable
final class _PluginManagementSnapshot {
  static const _pluginsEquality = ListEquality<PluginManagementMetadata>();

  final String? snapshotToken;
  final String? defaultPluginId;
  final int defaultIdleTimeoutMins;
  final List<PluginManagementMetadata> plugins;

  const _PluginManagementSnapshot({
    required this.snapshotToken,
    required this.defaultPluginId,
    required this.defaultIdleTimeoutMins,
    required this.plugins,
  });

  _PluginManagementSnapshot withSnapshotToken({required String snapshotToken}) {
    return _PluginManagementSnapshot(
      snapshotToken: snapshotToken,
      defaultPluginId: defaultPluginId,
      defaultIdleTimeoutMins: defaultIdleTimeoutMins,
      plugins: plugins,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PluginManagementSnapshot &&
            snapshotToken == other.snapshotToken &&
            defaultPluginId == other.defaultPluginId &&
            defaultIdleTimeoutMins == other.defaultIdleTimeoutMins &&
            _pluginsEquality.equals(plugins, other.plugins);
  }

  @override
  int get hashCode {
    return Object.hash(
      snapshotToken,
      defaultPluginId,
      defaultIdleTimeoutMins,
      _pluginsEquality.hash(plugins),
    );
  }
}

class PluginManagementPluginNotFoundException implements Exception {
  const PluginManagementPluginNotFoundException(this.pluginId);

  final String pluginId;
}

class PluginManagementConflictException implements Exception {
  const PluginManagementConflictException(this.conflict);

  final PluginLifecycleConflict conflict;
}

class PluginManagementCommandFailedException implements Exception {
  const PluginManagementCommandFailedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ActivePluginCommand {
  _ActivePluginCommand({required this.request});

  final PluginLifecycleCommandRequest request;
  final Completer<PluginManagementResponse> completer = Completer<PluginManagementResponse>();
}
