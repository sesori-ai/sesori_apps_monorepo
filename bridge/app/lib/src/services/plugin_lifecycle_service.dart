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
  Map<String, PluginSessionOptionsScope> sessionOptionsScopeById,
});

typedef RegisteredPluginMetadata = ({
  String id,
  String displayName,
  PluginActivationPolicy activationPolicy,
  PluginResidencyPolicy residencyPolicy,
  PluginSessionOptionsScope sessionOptionsScope,
  Set<PluginControlCapability> managementCapabilities,
  bool supportsPromptAttachments,
});

typedef PluginStartupPolicy = ({
  List<String> eligiblePluginIds,
  List<String> eagerPluginIds,
  String? defaultPluginId,
});

/// One producer-coalesced install progress update, ready for wire mapping.
typedef PluginInstallProgressUpdate = ({
  String pluginId,
  PluginInstallPhase phase,
  int? percent,
  String? message,
});

typedef PluginAuthenticationProgressUpdate = ({String pluginId, PluginAuthenticationProgress progress});

class const PluginIdleTimerScheduler() {
  Timer schedule({required Duration duration, required void Function() onElapsed}) {
    return Timer(duration, onElapsed);
  }
}

class PluginLifecycleService({
  required final PluginLifecycleRepository _lifecycleRepository,
  required final String _preferredDefaultPluginId,
  required final BridgeSettingsRepository _bridgeSettingsRepository,
  required final PluginIdleTimerScheduler _idleTimerScheduler,
  required final BridgeIdProvider _bridgeIdProvider,
}) {
  List<RegisteredPluginMetadata>? _registeredPlugins;
  Set<String>? _knownPluginIds;
  Map<String, PluginResidencyPolicy>? _residencyPolicyById;
  late Map<String, PluginSessionOptionsScope> _sessionOptionsScopeById;
  Map<String, Set<PluginControlCapability>>? _managementCapabilitiesById;
  List<String>? _eligiblePluginIds;
  Set<String> _startAllowedPluginIds = {};
  Map<String, PluginMetadata> _metadataById = <String, PluginMetadata>{};
  Map<String, PluginSetupStatus>? _setupById;
  BehaviorSubject<List<PluginMetadata>>? _metadataSubject;
  BehaviorSubject<List<String>>? _readyPluginIdsSubject;
  final StreamController<String> _managementSnapshotTokenController = StreamController<String>.broadcast(sync: true);
  final StreamController<PluginInstallProgressUpdate> _installProgressController =
      StreamController<PluginInstallProgressUpdate>.broadcast(sync: true);
  final StreamController<PluginAuthenticationProgressUpdate> _authenticationProgressController =
      StreamController<PluginAuthenticationProgressUpdate>.broadcast(sync: true);
  final Map<String, DateTime> _lastInstallDownloadEmit = {};
  StreamSubscription<List<PluginLifecycleSnapshot>>? _runtimeSubscription;
  Future<void>? _disposeFuture;
  Future<void> _settingsMutationTail = Future<void>.value();
  final Map<String, _ActivePluginCommand> _activePluginCommands = {};
  final Map<String, _ActivePluginAuthentication> _activePluginAuthentications = {};
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
    _sessionOptionsScopeById = Map<String, PluginSessionOptionsScope>.unmodifiable({
      for (final plugin in plugins) plugin.id: plugin.sessionOptionsScope,
    });
    _managementCapabilitiesById = Map<String, Set<PluginControlCapability>>.unmodifiable({
      for (final plugin in plugins) plugin.id: Set<PluginControlCapability>.unmodifiable(plugin.managementCapabilities),
    });
  }

  Set<String> uncontrollableDisabledPluginIds({required Set<String> disabledPluginIds}) {
    if (_eligiblePluginIds != null) throw StateError("Plugin lifecycle is already initialized.");
    return Set<String>.unmodifiable(
      disabledPluginIds.intersection(
        _pluginIdsWithout(capability: PluginControlCapability.lifecycle),
      ),
    );
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
    final eagerPluginIds = List<String>.unmodifiable([
      for (final plugin in registeredPlugins)
        if (eligiblePluginIds.contains(plugin.id) &&
            setupReadyPluginIds.contains(plugin.id) &&
            plugin.activationPolicy == PluginActivationPolicy.eager)
          plugin.id,
    ]);
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
      eagerPluginIds: eagerPluginIds,
      defaultPluginId: defaultPluginId,
    );
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
      sessionOptionsScopeById: _sessionOptionsScopeById,
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
    final snapshot = _requireManagementSnapshot();
    return _buildManagementResponse(snapshot: snapshot, bridgeId: _requireBridgeId());
  }

  _PluginManagementSnapshot _requireManagementSnapshot() {
    if (_registeredPlugins == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    final snapshot = _lastPublishedManagementSnapshot;
    if (snapshot == null) throw StateError("Plugin management snapshot is not ready.");
    return snapshot;
  }

  PluginManagementResponse _buildManagementResponse({
    required _PluginManagementSnapshot snapshot,
    required String bridgeId,
  }) {
    return PluginManagementResponse(
      snapshotToken: snapshot.snapshotToken,
      bridgeId: bridgeId,
      defaultPluginId: snapshot.defaultPluginId,
      defaultIdleTimeoutMins: snapshot.defaultIdleTimeoutMins,
      plugins: snapshot.plugins,
    );
  }

  PluginManagementResponse get _managementSnapshotAfterMutation {
    final snapshot = _requireManagementSnapshot();
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null) throw const PluginManagementMutationOutcomeUncertainException();
    return _buildManagementResponse(snapshot: snapshot, bridgeId: bridgeId);
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
    _requireManagementCapability(
      pluginId: pluginId,
      capability: switch (request) {
        PluginLifecycleEnableRequest() ||
        PluginLifecycleDisableRequest() ||
        PluginLifecycleRestartRequest() => PluginControlCapability.lifecycle,
        PluginLifecycleRefreshRequest() => PluginControlCapability.setupRefresh,
        PluginLifecycleInstallRequest() => PluginControlCapability.install,
      },
    );
    final active = _activePluginCommands[pluginId];
    if (active != null) {
      if (active.request == request) {
        // A joined install returns the accepted snapshot immediately; the
        // in-flight install keeps streaming progress and owns the slot.
        return request is PluginLifecycleInstallRequest
            ? Future<PluginManagementResponse>.value(_managementSnapshotAfterMutation)
            : active.completer.future;
      }
      throw PluginManagementConflictException(
        PluginLifecycleConflict(
          pluginId: pluginId,
          reasons: const [PluginLifecycleConflictReason.transitioning],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }
    if (_activePluginAuthentications.containsKey(pluginId)) {
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
    if (request is PluginLifecycleInstallRequest) {
      // Accepted-immediately: a download can run for minutes, far beyond any
      // relay request budget. The HTTP response is the current snapshot;
      // progress streams via SSE and the terminal outcome invalidates the
      // management snapshot. The slot stays occupied until the install ends.
      unawaited(_executeInstall(pluginId: pluginId, command: command));
      return Future<PluginManagementResponse>.value(_managementSnapshotAfterMutation);
    }
    unawaited(_executeCommand(pluginId: pluginId, command: command));
    return command.completer.future;
  }

  Stream<PluginInstallProgressUpdate> get installProgress => _installProgressController.stream;

  Stream<PluginAuthenticationProgressUpdate> get authenticationProgress => _authenticationProgressController.stream;

  Future<PluginAuthenticationChallengeResponse> authenticate({required String pluginId}) {
    final knownPluginIds = _knownPluginIds;
    if (knownPluginIds == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    if (!knownPluginIds.contains(pluginId)) {
      throw PluginManagementPluginNotFoundException(pluginId);
    }
    _requireBridgeId();
    final active = _activePluginAuthentications[pluginId];
    if (active != null) return active.challenge.future;
    if (!_supportsManagementCapability(
      pluginId: pluginId,
      capability: PluginControlCapability.authentication,
    )) {
      throw PluginAuthenticationConflictException(
        PluginAuthenticationConflict(
          pluginId: pluginId,
          reasons: const [PluginAuthenticationConflictReason.unsupported],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }
    if (_activePluginCommands.containsKey(pluginId)) {
      throw PluginAuthenticationConflictException(
        PluginAuthenticationConflict(
          pluginId: pluginId,
          reasons: const [PluginAuthenticationConflictReason.inFlight],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }
    if (_setupById![pluginId] is! PluginSetupAuthenticationRequired) {
      throw PluginAuthenticationConflictException(
        PluginAuthenticationConflict(
          pluginId: pluginId,
          reasons: const [PluginAuthenticationConflictReason.setupNotRequired],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }

    final operation = _lifecycleRepository.authenticate(pluginId: pluginId);
    final authentication = _ActivePluginAuthentication(operation: operation);
    _activePluginAuthentications[pluginId] = authentication;
    _publishManagementIfChanged();
    unawaited(_executeAuthentication(pluginId: pluginId, authentication: authentication));
    return authentication.challenge.future;
  }

  Future<SuccessEmptyResponse> cancelAuthentication({required String pluginId}) async {
    final knownPluginIds = _knownPluginIds;
    if (knownPluginIds == null || _setupById == null) {
      throw StateError("Plugin lifecycle has not been initialized.");
    }
    if (!knownPluginIds.contains(pluginId)) {
      throw PluginManagementPluginNotFoundException(pluginId);
    }
    _requireBridgeId();
    if (!_supportsManagementCapability(
      pluginId: pluginId,
      capability: PluginControlCapability.authentication,
    )) {
      throw PluginAuthenticationConflictException(
        PluginAuthenticationConflict(
          pluginId: pluginId,
          reasons: const [PluginAuthenticationConflictReason.unsupported],
          current: _managementRowForPluginId(pluginId),
        ),
      );
    }
    final active = _activePluginAuthentications[pluginId];
    active?.operation.abort();
    if (active != null) await active.settled.future;
    return const SuccessEmptyResponse();
  }

  Future<void> _executeAuthentication({
    required String pluginId,
    required _ActivePluginAuthentication authentication,
  }) async {
    PluginAuthenticationProgress progress;
    try {
      PluginAuthenticationProgress? terminal;
      await for (final event in authentication.operation.events) {
        terminal = switch (event) {
          PluginAuthenticationDeviceCodeChallenge(:final verificationUri, :final userCode) => () {
            if (verificationUri.scheme != "https") {
              throw StateError("Plugin authentication returned a non-HTTPS verification URL.");
            }
            if (!authentication.challenge.isCompleted) {
              authentication.challenge.complete(
                PluginAuthenticationChallengeResponse.deviceCode(
                  verificationUrl: verificationUri.toString(),
                  userCode: userCode,
                ),
              );
            }
            return terminal;
          }(),
          PluginAuthenticationCompleted() => const PluginAuthenticationProgress.completed(),
          PluginAuthenticationFailed(:final message) => () {
            Log.w('Plugin "$pluginId" authentication failed: $message');
            return const PluginAuthenticationProgress.failed(
              message: "Authentication failed. Check the bridge logs for details.",
            );
          }(),
        };
      }
      progress = terminal ?? const PluginAuthenticationProgress.failed(message: "Authentication ended unexpectedly.");
    } on PluginStartAbortedException {
      progress = const PluginAuthenticationProgress.cancelled();
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" authentication failed', error, stackTrace);
      progress = const PluginAuthenticationProgress.failed(
        message: "Authentication failed. Check the bridge logs for details.",
      );
    }

    try {
      final setup = await _inspectAfterAuthentication(pluginId: pluginId);
      if (progress is PluginAuthenticationCompletedProgress && setup is! PluginSetupReady) {
        progress = const PluginAuthenticationProgress.failed(
          message: "Authentication finished, but the harness still requires setup.",
        );
      }
    } on Object catch (error, stackTrace) {
      Log.w('Plugin "$pluginId" setup inspection after authentication failed', error, stackTrace);
      if (progress is! PluginAuthenticationCancelledProgress) {
        progress = const PluginAuthenticationProgress.failed(
          message: "Authentication finished, but setup could not be verified.",
        );
      }
    }
    if (identical(_activePluginAuthentications[pluginId], authentication)) {
      _activePluginAuthentications.remove(pluginId);
    }
    if (!authentication.challenge.isCompleted) {
      authentication.challenge.completeError(
        const PluginAuthenticationChallengeUnavailableException(),
      );
    }
    if (!_authenticationProgressController.isClosed) {
      _authenticationProgressController.add((pluginId: pluginId, progress: progress));
    }
    _publishManagementIfChanged();
    authentication.settled.complete();
  }

  Future<PluginSetupStatus> _inspectAfterAuthentication({required String pluginId}) async {
    final inspected = await _lifecycleRepository.inspect(
      pluginIds: {pluginId},
      markUnselectedNotInspected: false,
    );
    final setup = inspected[pluginId];
    if (setup == null) throw StateError('Plugin "$pluginId" inspection returned no result.');
    _applyInspectedSetup(pluginId: pluginId, setup: setup);
    if (setup is PluginSetupReady && _requireEligiblePluginIds().contains(pluginId)) {
      _handleRuntimeCommandResult(
        pluginId: pluginId,
        result: await _lifecycleRepository.start(pluginId: pluginId),
      );
    }
    return setup;
  }

  Future<void> _executeInstall({
    required String pluginId,
    required _ActivePluginCommand command,
  }) async {
    try {
      RuntimeProvisionProgress? terminal;
      // Stop at the terminal event instead of draining the stream: the install
      // service still sweeps superseded versions after yielding ProvisionReady,
      // and the phone should not wait on that housekeeping.
      await for (final event in _lifecycleRepository.installRuntime(pluginId: pluginId)) {
        switch (event) {
          case ProvisionDownloading(:final receivedBytes, :final totalBytes):
            _emitInstallProgress(
              pluginId: pluginId,
              phase: PluginInstallPhase.downloading,
              percent: (totalBytes != null && totalBytes > 0)
                  ? (receivedBytes * 100 ~/ totalBytes).clamp(0, 100)
                  : null,
              message: null,
            );
          case ProvisionVerifying():
            _emitInstallProgress(pluginId: pluginId, phase: PluginInstallPhase.verifying, percent: null, message: null);
          case ProvisionExtracting():
            _emitInstallProgress(
              pluginId: pluginId,
              phase: PluginInstallPhase.extracting,
              percent: null,
              message: null,
            );
          case ProvisionResolving() || ProvisionNotice():
            break;
          case ProvisionReady() || ProvisionFailed():
            terminal = event;
        }
        // The install service still sweeps superseded versions after yielding
        // its terminal event; the phone must not wait on that housekeeping.
        if (terminal != null) break;
      }
      switch (terminal) {
        case ProvisionReady():
          _emitInstallProgress(pluginId: pluginId, phase: PluginInstallPhase.finalizing, percent: null, message: null);
          await _enable(pluginId: pluginId, command: command);
          // The binary is installed, but setup can still be blocked (most
          // often authentication). Report completed only when the harness
          // actually became usable; otherwise the phone would show success
          // while the card stays blocked.
          final setup = _requireSetupById()[pluginId];
          _emitInstallProgress(
            pluginId: pluginId,
            phase: setup is PluginSetupReady ? PluginInstallPhase.completed : PluginInstallPhase.failed,
            percent: null,
            message: setup is PluginSetupReady
                ? null
                : "The runtime installed, but the harness still needs setup. Check its status.",
          );
        case ProvisionFailed():
          // Descriptor failure text is not a trusted wire payload; the phone
          // gets a fixed message and the detail stays in the bridge log.
          Log.w('Plugin "$pluginId" managed runtime install failed: ${terminal.message}');
          _emitInstallProgress(
            pluginId: pluginId,
            phase: PluginInstallPhase.failed,
            percent: null,
            message: "The runtime could not be installed. Check the bridge logs for details.",
          );
        case _:
          _emitInstallProgress(
            pluginId: pluginId,
            phase: PluginInstallPhase.failed,
            percent: null,
            message: "The install ended without a result.",
          );
      }
    } on PluginStartAbortedException {
      // Shutdown aborted the install; the next attempt redoes it cleanly.
      _emitInstallProgress(
        pluginId: pluginId,
        phase: PluginInstallPhase.failed,
        percent: null,
        message: "The install was interrupted by a bridge shutdown.",
      );
    } on Object catch (error, stackTrace) {
      // The wire message stays generic; the local log keeps the diagnostic
      // detail (post-install enable/start errors may contain paths).
      Log.w('Plugin "$pluginId" managed runtime install failed', error, stackTrace);
      _emitInstallProgress(
        pluginId: pluginId,
        phase: PluginInstallPhase.failed,
        percent: null,
        message: "The runtime installed state could not be completed. Check the bridge logs.",
      );
    } finally {
      if (identical(_activePluginCommands[pluginId], command)) {
        _activePluginCommands.remove(pluginId);
      }
      _publishManagementIfChanged();
      // The install completer is never awaited (the HTTP response returned at
      // acceptance; a joined duplicate also returns immediately), so it is
      // deliberately left unsettled.
    }
  }

  static const Duration _installPercentMinInterval = Duration(milliseconds: 250);

  void _emitInstallProgress({
    required String pluginId,
    required PluginInstallPhase phase,
    required int? percent,
    required String? message,
  }) {
    if (_installProgressController.isClosed) return;
    // Producer-side coalescing: repeated downloading-percent updates are
    // rate-limited; phase changes and terminal events always emit.
    if (phase == PluginInstallPhase.downloading) {
      final now = DateTime.now();
      final last = _lastInstallDownloadEmit[pluginId];
      if (last != null && now.difference(last) < _installPercentMinInterval) return;
      _lastInstallDownloadEmit[pluginId] = now;
    } else {
      _lastInstallDownloadEmit.remove(pluginId);
    }
    _installProgressController.add((pluginId: pluginId, phase: phase, percent: percent, message: message));
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
    switch (request) {
      case PluginIdleTimeoutApplyAllRequest():
        break;
      case PluginIdleTimeoutSetOverrideRequest(:final pluginId) ||
          PluginIdleTimeoutClearOverrideRequest(:final pluginId):
        _requireManagementCapability(
          pluginId: pluginId,
          capability: PluginControlCapability.idleTimeout,
        );
    }
    return _withSettingsMutationTail(() async {
      _requireBridgeId();
      await _bridgeSettingsRepository.mutateSettings(
        mutation: ({required current}) {
          final plugins = switch (request) {
            PluginIdleTimeoutApplyAllRequest(:final idleTimeoutMins) => current.plugins.withDefaultIdleTimeout(
              idleTimeoutMins: idleTimeoutMins,
              clearOverridePluginIds: _pluginIdsSupporting(capability: PluginControlCapability.idleTimeout),
            ),
            PluginIdleTimeoutSetOverrideRequest(:final pluginId, :final idleTimeoutMins) =>
              current.plugins.withPluginIdleTimeout(pluginId: pluginId, idleTimeoutMins: idleTimeoutMins),
            PluginIdleTimeoutClearOverrideRequest(:final pluginId) => current.plugins.withPluginIdleTimeout(
              pluginId: pluginId,
              idleTimeoutMins: null,
            ),
          };
          _requireBridgeId();
          return current.copyWith(plugins: plugins);
        },
      );
      _syncIdleTimers(_lifecycleRepository.snapshot);
      _publishManagementIfChanged();
      return _managementSnapshotAfterMutation;
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
        case PluginLifecycleInstallRequest():
          throw StateError("install commands are dispatched through _executeInstall");
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
        command.completer.complete(_managementSnapshotAfterMutation);
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
    _applyInspectedSetup(pluginId: pluginId, setup: setup);
    return setup;
  }

  void _applyInspectedSetup({required String pluginId, required PluginSetupStatus setup}) {
    _setupById = Map<String, PluginSetupStatus>.unmodifiable({..._requireSetupById(), pluginId: setup});
    if (_requireEligiblePluginIds().contains(pluginId) && setup is PluginSetupReady) {
      _startAllowedPluginIds.add(pluginId);
    } else {
      _startAllowedPluginIds.remove(pluginId);
    }
    _applyAccess();
    _applyRuntimeSnapshots(_lifecycleRepository.snapshot);
  }

  Future<void> _persistPluginDisabled({required String pluginId, required bool disabled}) {
    return _withSettingsMutationTail(() async {
      await _bridgeSettingsRepository.mutateSettings(
        mutation: ({required current}) => current.plugins.isDisabled(pluginId: pluginId) == disabled
            ? current
            : current.copyWith(
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
              supportsPromptAttachments: plugin.supportsPromptAttachments,
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
      runtimeVersion: setup.runtimeVersion,
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
      authenticationState: _activePluginAuthentications.containsKey(plugin.id)
          ? PluginAuthenticationState.inProgress
          : PluginAuthenticationState.idle,
      idleTimeoutMins: _effectiveIdleTimeoutMins(plugin.id),
      hasIdleTimeoutOverride: settings.plugins.settingsByPluginId[plugin.id]?.idleTimeoutMins != null,
      managementCapabilities: {
        for (final capability in _managementCapabilitiesForPluginId(pluginId: plugin.id))
          _mapManagementCapability(capability: capability),
      },
      actionHint: setup.actionHint ?? _managementActionHint(snapshot.state),
    );
  }

  PluginManagementCapability _mapManagementCapability({required PluginControlCapability capability}) =>
      switch (capability) {
        PluginControlCapability.lifecycle => PluginManagementCapability.lifecycle,
        PluginControlCapability.setupRefresh => PluginManagementCapability.setupRefresh,
        PluginControlCapability.idleTimeout => PluginManagementCapability.idleTimeout,
        PluginControlCapability.install => PluginManagementCapability.install,
        PluginControlCapability.authentication => PluginManagementCapability.authentication,
      };

  Set<String> _pluginIdsSupporting({required PluginControlCapability capability}) {
    final capabilitiesById = _managementCapabilitiesById;
    if (capabilitiesById == null) throw StateError("Plugins have not been registered.");
    return {
      for (final MapEntry(key: pluginId, value: capabilities) in capabilitiesById.entries)
        if (capabilities.contains(capability)) pluginId,
    };
  }

  Set<String> _pluginIdsWithout({required PluginControlCapability capability}) {
    final capabilitiesById = _managementCapabilitiesById;
    if (capabilitiesById == null) throw StateError("Plugins have not been registered.");
    return {
      for (final MapEntry(key: pluginId, value: capabilities) in capabilitiesById.entries)
        if (!capabilities.contains(capability)) pluginId,
    };
  }

  Set<PluginControlCapability> _managementCapabilitiesForPluginId({required String pluginId}) {
    final capabilitiesById = _managementCapabilitiesById;
    if (capabilitiesById == null) throw StateError("Plugins have not been registered.");
    return capabilitiesById[pluginId] ?? (throw StateError('Plugin "$pluginId" is not registered.'));
  }

  void _requireManagementCapability({required String pluginId, required PluginControlCapability capability}) {
    if (_supportsManagementCapability(pluginId: pluginId, capability: capability)) return;
    throw PluginManagementConflictException(
      PluginLifecycleConflict(
        pluginId: pluginId,
        reasons: const [PluginLifecycleConflictReason.unsupported],
        current: _managementRowForPluginId(pluginId),
      ),
    );
  }

  bool _supportsManagementCapability({required String pluginId, required PluginControlCapability capability}) {
    return _managementCapabilitiesForPluginId(pluginId: pluginId).contains(capability);
  }

  bool _supportsIdleSuspension({required String pluginId}) {
    return _supportsManagementCapability(
          pluginId: pluginId,
          capability: PluginControlCapability.lifecycle,
        ) &&
        _supportsManagementCapability(
          pluginId: pluginId,
          capability: PluginControlCapability.idleTimeout,
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
    try {
      await _installProgressController.close();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    for (final authentication in _activePluginAuthentications.values) {
      authentication.operation.abort();
    }
    try {
      await Future.wait([
        for (final authentication in _activePluginAuthentications.values) authentication.settled.future,
      ]);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    try {
      await _authenticationProgressController.close();
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
      if (!_supportsIdleSuspension(pluginId: snapshot.pluginId) || timeoutMins <= 0 || !_isIdleCandidate(snapshot)) {
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
    if (!_supportsIdleSuspension(pluginId: pluginId)) return;
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
final class const _PluginManagementSnapshot({
  required final String? snapshotToken,
  required final String? defaultPluginId,
  required final int defaultIdleTimeoutMins,
  required final List<PluginManagementMetadata> plugins,
}) {
  static const _pluginsEquality = ListEquality<PluginManagementMetadata>();

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

class const PluginManagementPluginNotFoundException(final String pluginId) implements Exception;

class const PluginManagementConflictException(final PluginLifecycleConflict conflict) implements Exception;

class const PluginAuthenticationConflictException(final PluginAuthenticationConflict conflict) implements Exception;

class const PluginAuthenticationChallengeUnavailableException() implements Exception;

class const PluginManagementCommandFailedException(final String message) implements Exception {
  @override
  String toString() => message;
}

class const PluginManagementMutationOutcomeUncertainException() implements Exception;

class _ActivePluginCommand({required final PluginLifecycleCommandRequest request}) {
  final Completer<PluginManagementResponse> completer = Completer<PluginManagementResponse>();
}

class _ActivePluginAuthentication({required final PluginRuntimeAuthenticationOperation operation}) {
  final Completer<PluginAuthenticationChallengeResponse> challenge = Completer<PluginAuthenticationChallengeResponse>();
  final Completer<void> settled = Completer<void>();
}
