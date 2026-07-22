import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PluginRuntimeState;
import "package:sesori_shared/sesori_shared.dart" as shared show PluginRuntimeState;

import "../bridge/runtime/plugin_runtime.dart";
import "../repositories/bridge_settings.dart";
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
    required BridgeSettingsRepository bridgeSettingsRepository,
    required PluginIdleTimerScheduler idleTimerScheduler,
  }) : _lifecycleRepository = lifecycleRepository,
       _bridgeSettingsRepository = bridgeSettingsRepository,
       _idleTimerScheduler = idleTimerScheduler;

  final PluginLifecycleRepository _lifecycleRepository;
  final BridgeSettingsRepository _bridgeSettingsRepository;
  final PluginIdleTimerScheduler _idleTimerScheduler;
  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  List<String>? _eligiblePluginIds;
  Set<String> _startAllowedPluginIds = <String>{};
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  BehaviorSubject<List<String>>? _readyPluginIdsSubject;
  BehaviorSubject<PluginManagementResponse>? _managementSubject;
  final StreamController<int> _managementRevisionController = StreamController<int>.broadcast(sync: true);
  StreamSubscription<List<PluginLifecycleSnapshot>>? _runtimeSubscription;
  Future<void>? _disposeFuture;
  Future<void> _settingsMutationTail = Future<void>.value();
  final Map<String, _ActivePluginCommand> _pluginCommands = <String, _ActivePluginCommand>{};
  final Map<String, ({Duration duration, Timer timer})> _idleTimers = {};
  int _managementRevision = 0;
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
    _eligiblePluginIds = List<String>.unmodifiable([
      for (final plugin in registeredPlugins)
        if (!disabledPluginIds.contains(plugin.id)) plugin.id,
    ]);
    _startAllowedPluginIds = {
      for (final pluginId in _eligiblePluginIds!)
        if (setupById[pluginId] is PluginSetupReady) pluginId,
    };
    _rebuildMetadata();
    _applyAccess();
    _metadataSubject = BehaviorSubject<List<PluginMetadata>>.seeded(_orderedMetadata());
    _readyPluginIdsSubject = BehaviorSubject<List<String>>.seeded(
      _buildReadyPluginIds(_lifecycleRepository.snapshot),
    );
    _managementSubject = BehaviorSubject<PluginManagementResponse>.seeded(
      _buildManagementResponse(revision: _managementRevision),
    );
    _runtimeSubscription = _lifecycleRepository.snapshots.listen(_applyRuntimeSnapshots);
    return (
      eligiblePluginIds: _eligiblePluginIds!,
      defaultPluginId: _selectableDefaultPluginId(),
    );
  }

  void applyAvailability({required Set<String> availablePluginIds}) {
    final setupById = _requireSetupById();
    _startAllowedPluginIds = {
      for (final pluginId in _requireEligiblePluginIds())
        if (availablePluginIds.contains(pluginId) && setupById[pluginId] is PluginSetupReady) pluginId,
    };
    _applyAccess();
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
  }

  PluginCompositionView get compositionView {
    final knownPluginIds = _knownPluginIds;
    if (knownPluginIds == null) throw StateError("Plugin lifecycle has not been initialized.");
    return (
      knownPluginIds: knownPluginIds,
      eligiblePluginIds: _requireEligiblePluginIds(),
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
        for (final plugin in registeredPlugins)
          _mapSetupMetadata(
            pluginId: plugin.id,
            displayName: plugin.displayName,
            setup: setupById[plugin.id]!,
          ),
      ],
    );
  }

  PluginManagementResponse get managementSnapshot {
    _requireInitialized();
    return _buildManagementResponse(revision: _managementRevision);
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

  Stream<PluginManagementResponse> get managementSnapshots {
    final subject = _managementSubject;
    if (subject == null) throw StateError("Plugin lifecycle has not been initialized.");
    return subject.stream;
  }

  Stream<int> get managementRevisions => _managementRevisionController.stream;

  Future<PluginManagementResponse> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  }) {
    _requireKnownPlugin(pluginId);
    final active = _pluginCommands[pluginId];
    if (active != null) {
      if (active.request == request) return active.completer.future;
      throw PluginManagementConflictException(
        PluginLifecycleConflict(
          pluginId: pluginId,
          reasons: const [PluginLifecycleConflictReason.transitioning],
          current: _managementRow(pluginId),
        ),
      );
    }

    final command = _ActivePluginCommand(request: request);
    _pluginCommands[pluginId] = command;
    unawaited(_executeCommand(pluginId: pluginId, command: command));
    return command.completer.future;
  }

  Future<PluginManagementResponse> updateIdleTimeout({required PluginIdleTimeoutUpdateRequest request}) {
    _requireInitialized();
    switch (request) {
      case PluginIdleTimeoutApplyAllRequest():
        break;
      case PluginIdleTimeoutSetOverrideRequest(:final pluginId):
        _requireKnownPlugin(pluginId);
      case PluginIdleTimeoutClearOverrideRequest(:final pluginId):
        _requireKnownPlugin(pluginId);
    }
    return _withSettingsTail(() async {
      final current = await _bridgeSettingsRepository.loadSettings();
      final updatedPlugins = switch (request) {
        PluginIdleTimeoutApplyAllRequest(:final idleTimeoutMins) => current.plugins.withDefaultIdleTimeout(
          idleTimeoutMins: idleTimeoutMins,
          clearOverridePluginIds: _knownPluginIds!,
        ),
        PluginIdleTimeoutSetOverrideRequest(:final pluginId, :final idleTimeoutMins) =>
          current.plugins.withPluginIdleTimeout(pluginId: pluginId, idleTimeoutMins: idleTimeoutMins),
        PluginIdleTimeoutClearOverrideRequest(:final pluginId) => current.plugins.withPluginIdleTimeout(
          pluginId: pluginId,
          idleTimeoutMins: null,
        ),
      };
      await _bridgeSettingsRepository.saveSettings(settings: current.copyWith(plugins: updatedPlugins));
      _syncIdleTimers(_lifecycleRepository.snapshot);
      _publishManagementIfChanged();
      return managementSnapshot;
    });
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

    if (identical(_pluginCommands[pluginId], command)) _pluginCommands.remove(pluginId);
    _publishManagementIfChanged();
    if (failure == null) {
      command.completer.complete(managementSnapshot);
    } else {
      command.completer.completeError(failure, failureStackTrace);
    }
  }

  Future<void> _enable({required String pluginId, required _ActivePluginCommand command}) async {
    if (!_requireEligiblePluginIds().contains(pluginId)) {
      await _persistPluginDisabled(pluginId: pluginId, disabled: false);
      _setEligibility(pluginId: pluginId, eligible: true);
    }
    final setup = await _inspectForCommand(pluginId: pluginId, command: command);
    if (setup is! PluginSetupReady) return;
    _handleRuntimeCommandResult(
      pluginId: pluginId,
      result: await _lifecycleRepository.start(pluginId: pluginId),
    );
  }

  Future<void> _disable({required String pluginId, required PluginStopMode mode}) async {
    if (!_requireEligiblePluginIds().contains(pluginId)) return;
    final result = await _lifecycleRepository.disable(pluginId: pluginId, intent: _mapStopIntent(mode));
    switch (result) {
      case PluginRuntimeCommandConflict():
        _handleRuntimeCommandResult(pluginId: pluginId, result: result);
      case PluginRuntimeCommandFailed():
        _handleRuntimeCommandResult(pluginId: pluginId, result: result);
      case PluginRuntimeCommandApplied() || PluginRuntimeCommandCurrent():
        break;
    }

    try {
      await _persistPluginDisabled(pluginId: pluginId, disabled: true);
    } on Object catch (error) {
      _lifecycleRepository.restoreEnabledAfterDisable(pluginId: pluginId);
      _startAllowedPluginIds = {
        ..._startAllowedPluginIds,
        if (_requireSetupById()[pluginId] is PluginSetupReady) pluginId,
      };
      _applyAccess();
      throw PluginManagementCommandFailedException(error.toString());
    }
    _lifecycleRepository.commitDisabled(pluginId: pluginId);
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
          current: _managementRow(pluginId),
        ),
      );
    }
    final setup = await _inspectForCommand(pluginId: pluginId, command: command);
    if (setup is! PluginSetupReady) return;
    _handleRuntimeCommandResult(
      pluginId: pluginId,
      result: await _lifecycleRepository.restart(pluginId: pluginId, intent: _mapStopIntent(mode)),
    );
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
    if (!identical(_pluginCommands[pluginId], command)) {
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
    return _withSettingsTail(() async {
      final current = await _bridgeSettingsRepository.loadSettings();
      if (current.plugins.isDisabled(pluginId: pluginId) == disabled) return;
      await _bridgeSettingsRepository.saveSettings(
        settings: current.copyWith(
          plugins: current.plugins.withPluginDisabled(pluginId: pluginId, disabled: disabled),
        ),
      );
    });
  }

  Future<T> _withSettingsTail<T>(Future<T> Function() operation) {
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
    final metadataSubject = _metadataSubject;
    if (metadataSubject != null && !metadataSubject.isClosed) metadataSubject.add(_orderedMetadata());
    _publishReadyPluginIds(snapshots);
    _syncIdleTimers(snapshots);
    if (_pluginCommands.isEmpty && snapshots.every((snapshot) => snapshot.transitionSettled)) {
      _publishManagementIfChanged();
    }
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
    final defaultId = _selectableDefaultPluginId();
    return List<PluginMetadata>.unmodifiable([
      for (final pluginId in _requireEligiblePluginIds())
        _metadataById[pluginId]!.copyWith(isDefault: pluginId == defaultId),
    ]);
  }

  String? _selectableDefaultPluginId() {
    for (final pluginId in _requireEligiblePluginIds()) {
      final snapshot = _lifecycleRepository.snapshot.where((entry) => entry.pluginId == pluginId).firstOrNull;
      if (snapshot != null && _isSelectable(snapshot)) return pluginId;
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

  PluginManagementResponse _buildManagementResponse({required int revision}) {
    final settings = _bridgeSettingsRepository.currentSettings;
    return PluginManagementResponse(
      revision: revision,
      defaultPluginId: _selectableDefaultPluginId(),
      defaultIdleTimeoutMins: settings.plugins.defaults.idleTimeoutMins ?? defaultPluginIdleTimeoutMins,
      plugins: [for (final plugin in _registeredPlugins!) _managementRow(plugin.id)],
    );
  }

  PluginManagementMetadata _managementRow(String pluginId) {
    final plugin = _registeredPlugins!.singleWhere((candidate) => candidate.id == pluginId);
    final snapshot = _lifecycleRepository.snapshot.singleWhere((entry) => entry.pluginId == pluginId);
    final settings = _bridgeSettingsRepository.currentSettings;
    final setup = _mapSetupMetadata(
      pluginId: plugin.id,
      displayName: plugin.displayName,
      setup: snapshot.setup,
    );
    return PluginManagementMetadata(
      setup: setup,
      runtimeState: _mapRuntimeState(snapshot.state),
      workState: _mapWorkState(snapshot.workState),
      idleTimeoutMins: settings.plugins.idleTimeoutMinsFor(pluginId: pluginId),
      hasIdleTimeoutOverride: settings.plugins.settingsByPluginId[pluginId]?.idleTimeoutMins != null,
      actionHint: setup.actionHint ?? _managementActionHint(snapshot.state),
    );
  }

  void _publishManagementIfChanged() {
    final subject = _managementSubject;
    if (subject == null || subject.isClosed || _pluginCommands.isNotEmpty) return;
    if (_lifecycleRepository.snapshot.any((snapshot) => !snapshot.transitionSettled)) return;
    final next = _buildManagementResponse(revision: _managementRevision);
    if (subject.value.copyWith(revision: 0) == next.copyWith(revision: 0)) return;
    _managementRevision++;
    final changed = _buildManagementResponse(revision: _managementRevision);
    subject.add(changed);
    if (!_managementRevisionController.isClosed) _managementRevisionController.add(_managementRevision);
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
            current: _managementRow(pluginId),
          ),
        );
      case PluginRuntimeCommandFailed(:final message):
        throw PluginManagementCommandFailedException(message);
    }
  }

  PluginSetupMetadata _mapSetupMetadata({
    required String pluginId,
    required String displayName,
    required PluginSetupStatus setup,
  }) {
    return PluginSetupMetadata(
      id: pluginId,
      displayName: displayName,
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

  PluginStopIntent _mapStopIntent(PluginStopMode mode) => switch (mode) {
    PluginStopMode.safe => PluginStopIntent.safe,
    PluginStopMode.force => PluginStopIntent.force,
  };

  PluginLifecycleConflictReason _mapConflictReason(PluginRuntimeConflictReason reason) => switch (reason) {
    PluginRuntimeConflictReason.inFlight => PluginLifecycleConflictReason.inFlight,
    PluginRuntimeConflictReason.busy => PluginLifecycleConflictReason.busy,
    PluginRuntimeConflictReason.workStateUnknown => PluginLifecycleConflictReason.workStateUnknown,
    PluginRuntimeConflictReason.transitioning => PluginLifecycleConflictReason.transitioning,
    PluginRuntimeConflictReason.notEligible => PluginLifecycleConflictReason.notEnabled,
  };

  String? _managementActionHint(PluginRuntimeState state) => switch (state) {
    PluginRuntimeState.failed => "Check the bridge console and retry or refresh this plugin.",
    PluginRuntimeState.degraded => "Check the bridge console if this plugin needs attention.",
    PluginRuntimeState.blocked => "Resolve the local setup requirement, then refresh this plugin.",
    PluginRuntimeState.disabled ||
    PluginRuntimeState.dormant ||
    PluginRuntimeState.starting ||
    PluginRuntimeState.active ||
    PluginRuntimeState.stopping => null,
  };

  void _requireKnownPlugin(String pluginId) {
    if (!(_knownPluginIds?.contains(pluginId) ?? false)) {
      throw PluginManagementPluginNotFoundException(pluginId);
    }
  }

  void _requireInitialized() {
    if (_managementSubject == null) throw StateError("Plugin lifecycle has not been initialized.");
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

  List<String> _buildReadyPluginIds(List<PluginLifecycleSnapshot> snapshots) {
    final byId = <String, PluginLifecycleSnapshot>{
      for (final snapshot in snapshots) snapshot.pluginId: snapshot,
    };
    return List<String>.unmodifiable([
      for (final pluginId in _requireEligiblePluginIds())
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
    if (current.length == next.length && current.indexed.every((entry) => entry.$2 == next[entry.$1])) return;
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
        onElapsed: () => unawaited(_stopAfterIdleWindow(pluginId: snapshot.pluginId, timer: timer)),
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
    return _bridgeSettingsRepository.currentSettings.plugins.idleTimeoutMinsFor(pluginId: pluginId);
  }

  Future<void> _stopAfterIdleWindow({required String pluginId, required Timer timer}) async {
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

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposing = true;
    for (final entry in _idleTimers.values) {
      entry.timer.cancel();
    }
    _idleTimers.clear();
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final close in <Future<void> Function()>[
      () => _runtimeSubscription?.cancel() ?? Future<void>.value(),
      () => _metadataSubject?.close() ?? Future<void>.value(),
      () => _readyPluginIdsSubject?.close() ?? Future<void>.value(),
      () => _managementSubject?.close() ?? Future<void>.value(),
      _managementRevisionController.close,
    ]) {
      try {
        await close();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
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

class _ActivePluginCommand {
  _ActivePluginCommand({required this.request});

  final PluginLifecycleCommandRequest request;
  final Completer<PluginManagementResponse> completer = Completer<PluginManagementResponse>();
}

class PluginManagementPluginNotFoundException implements Exception {
  const PluginManagementPluginNotFoundException(this.pluginId);

  final String pluginId;
}

class PluginManagementBadRequestException implements Exception {
  const PluginManagementBadRequestException(this.message);

  final String message;

  @override
  String toString() => message;
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
