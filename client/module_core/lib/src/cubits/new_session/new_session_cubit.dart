import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/session/session_service.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../repositories/project_repository.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/models/new_session_selection_intent.dart";
import "../../services/new_session_options_service.dart";
import "../../services/new_session_plugin_service.dart";
import "../../services/new_session_selection_tracker.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  NewSessionCubit({
    required ConnectionService connectionService,
    required SessionService sessionService,
    required NewSessionPluginService newSessionPluginService,
    required NewSessionOptionsService newSessionOptionsService,
    required ProjectRepository projectRepository,
    required NewSessionSelectionTracker selectionTracker,
    required String projectId,
    required bool? initialSupportsDedicatedWorktrees,
  }) : _connectionService = connectionService,
       _sessionService = sessionService,
       _newSessionPluginService = newSessionPluginService,
       _newSessionOptionsService = newSessionOptionsService,
       _projectRepository = projectRepository,
       _selectionTracker = selectionTracker,
       _projectId = projectId,
       super(
         NewSessionState.idle(
           availablePlugins: const [],
           selectedPlugin: null,
           options: const NewSessionOptionsLoadingState(source: null),
           isPluginDiscoveryInFlight: false,
           // Notification/deep-link entry lacks project-list context; retain
           // the prior visible behavior until the project fetch completes.
           supportsDedicatedWorktrees: initialSupportsDedicatedWorktrees ?? true,
         ),
       ) {
    _wasConnected = _connectionService.currentStatus is ConnectionConnected;
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    unawaited(_discoverPlugins());
    unawaited(_loadProjectCapability());
  }

  final ConnectionService _connectionService;
  final SessionService _sessionService;
  final NewSessionPluginService _newSessionPluginService;
  final NewSessionOptionsService _newSessionOptionsService;
  final ProjectRepository _projectRepository;
  final NewSessionSelectionTracker _selectionTracker;
  final String _projectId;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late bool _wasConnected;
  int _loadGeneration = 0;
  int _projectLoadGeneration = 0;
  String? _discoveryBridgeId;

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (isClosed) return;
    final isConnected = status is ConnectionConnected;
    final reconnected = isConnected && !_wasConnected;
    _wasConnected = isConnected;
    if (!reconnected || state is NewSessionSending || state is NewSessionCreated) return;
    unawaited(_discoverPlugins());
    unawaited(_loadProjectCapability());
  }

  Future<void> _discoverPlugins() async {
    final generation = ++_loadGeneration;
    final beforeDiscovery = state.agentModelData;
    _emitStateUpdate(
      options: _loadingState(
        previousOptions: beforeDiscovery?.optionsState.data,
        source: beforeDiscovery?.optionsState.source,
      ),
      isPluginDiscoveryInFlight: true,
      supportsDedicatedWorktrees: null,
    );
    try {
      final response = await _newSessionPluginService.discover(
        currentSelectedPluginId: beforeDiscovery?.plugin?.id,
        currentSelectionBridgeId: _discoveryBridgeId,
      );
      if (!_canApplyLoad(generation: generation, pluginId: null)) return;

      switch (response) {
        case SuccessResponse(:final data):
          final bridgeIdentityChanged = _discoveryBridgeId != data.bridgeId;
          _discoveryBridgeId = data.bridgeId;
          final selectedPlugin = data.selected;
          final currentData = state.agentModelData;
          final isSamePlugin =
              !bridgeIdentityChanged &&
              currentData?.plugin?.id != null &&
              selectedPlugin?.id == currentData?.plugin?.id;
          final previousOptions = isSamePlugin ? currentData?.optionsState.data : null;
          final canLoad = selectedPlugin?.isRoutable ?? false;
          final source = data.optionsSource;
          emit(
            NewSessionState.idle(
              availablePlugins: data.plugins,
              selectedPlugin: selectedPlugin,
              options: canLoad
                  ? _loadingState(previousOptions: previousOptions, source: source)
                  : source == NewSessionOptionsSource.aggregate
                  ? const NewSessionOptionsUnavailableState()
                  : const NewSessionOptionsUnsupportedState(),
              isPluginDiscoveryInFlight: false,
              supportsDedicatedWorktrees: currentData?.supportsDedicatedWorktrees ?? false,
            ),
          );
          if (selectedPlugin != null && canLoad) {
            await _loadOptions(
              pluginId: selectedPlugin.id,
              generation: generation,
              refresh: false,
              previousOptions: previousOptions,
              source: source,
            );
          }
        case ErrorResponse(:final error):
          _emitDiscoveryError(reason: error.remoteFailureReason);
      }
    } on Object catch (error, stackTrace) {
      if (!_canApplyLoad(generation: generation, pluginId: null)) return;
      loge("New session: failed to discover plugins", error, stackTrace);
      _emitDiscoveryError(reason: RemoteFailureReason.unknown);
    }
  }

  void _emitDiscoveryError({required RemoteFailureReason reason}) {
    if (isClosed) return;
    // A failed discovery cannot identify the connected bridge (it may have
    // changed), so a later creation must not save a plugin preference under the
    // previous bridge's key.
    _discoveryBridgeId = null;
    final data = state.agentModelData;
    final options = switch (data?.optionsState) {
      NewSessionOptionsRefreshingState(:final options, :final source) => NewSessionOptionsAvailableState(
        options: options,
        source: source,
      ),
      NewSessionOptionsLoadingState(source: final source?) => NewSessionOptionsFailureState(
        reason: reason,
        source: source,
      ),
      NewSessionOptionsLoadingState(source: null) || null => const NewSessionOptionsLoadingState(source: null),
      final current => current,
    };
    emit(
      NewSessionState.error(
        reason: reason,
        availablePlugins: data?.plugins ?? const [],
        selectedPlugin: data?.plugin,
        options: options,
        isPluginDiscoveryInFlight: false,
        supportsDedicatedWorktrees: data?.supportsDedicatedWorktrees ?? false,
      ),
    );
  }

  Future<void> _loadProjectCapability() async {
    final generation = ++_projectLoadGeneration;
    try {
      final response = await _projectRepository.getProject(projectId: _projectId);
      if (isClosed || generation != _projectLoadGeneration || state is NewSessionCreated) return;
      switch (response) {
        case SuccessResponse(:final data):
          if (state.agentModelData?.supportsDedicatedWorktrees != data.supportsDedicatedWorktrees) {
            _emitStateUpdate(
              options: null,
              isPluginDiscoveryInFlight: null,
              supportsDedicatedWorktrees: data.supportsDedicatedWorktrees,
            );
          }
        case ErrorResponse(:final error):
          loge("New session: failed to load project $_projectId", error);
      }
    } on Object catch (error, stackTrace) {
      if (isClosed || generation != _projectLoadGeneration) return;
      loge("New session: failed to load project $_projectId", error, stackTrace);
    }
  }

  void selectPlugin({required String pluginId}) {
    final current = state;
    final data = current.agentModelData;
    if (current is NewSessionSending ||
        current is NewSessionCreated ||
        data == null ||
        data.isPluginDiscoveryInFlight ||
        data.plugin?.id == pluginId) {
      return;
    }

    final selectedPlugin = data.plugins.firstWhereOrNull((plugin) => plugin.id == pluginId);
    final source = data.optionsState.source;
    if (selectedPlugin == null || !selectedPlugin.isRoutable || source == null) return;

    final generation = ++_loadGeneration;
    emit(
      NewSessionState.idle(
        availablePlugins: data.plugins,
        selectedPlugin: selectedPlugin,
        options: NewSessionOptionsLoadingState(source: source),
        isPluginDiscoveryInFlight: false,
        supportsDedicatedWorktrees: data.supportsDedicatedWorktrees,
      ),
    );
    unawaited(
      _loadOptions(
        pluginId: pluginId,
        generation: generation,
        refresh: false,
        previousOptions: null,
        source: source,
      ),
    );
  }

  Future<void> refreshOptions() async {
    final current = state;
    final data = current.agentModelData;
    final plugin = data?.plugin;
    final source = data?.optionsState.source;
    if (current is NewSessionSending ||
        current is NewSessionCreated ||
        data == null ||
        data.isLoading ||
        source == null ||
        plugin == null ||
        !plugin.isRoutable) {
      return;
    }

    final generation = ++_loadGeneration;
    final previousOptions = data.optionsState.data;
    _emitStateUpdate(
      options: _loadingState(previousOptions: previousOptions, source: source),
      isPluginDiscoveryInFlight: false,
      supportsDedicatedWorktrees: null,
    );
    await _loadOptions(
      pluginId: plugin.id,
      generation: generation,
      refresh: true,
      previousOptions: previousOptions,
      source: source,
    );
  }

  Future<void> _loadOptions({
    required String pluginId,
    required int generation,
    required bool refresh,
    required NewSessionOptionsData? previousOptions,
    required NewSessionOptionsSource source,
  }) async {
    final NewSessionOptionsLoadResult result;
    try {
      result = await _newSessionOptionsService.load(
        projectId: _projectId,
        pluginId: pluginId,
        source: source,
        refresh: refresh,
        restoredSelection: _selectionTracker.read(projectId: _projectId, pluginId: pluginId),
        previousOptions: previousOptions,
      );
    } on Object catch (error, stackTrace) {
      if (!_canApplyLoad(generation: generation, pluginId: pluginId)) return;
      loge("New session: failed to load options", error, stackTrace);
      _emitStateUpdate(
        options: NewSessionOptionsFailureState(reason: RemoteFailureReason.unknown, source: source),
        isPluginDiscoveryInFlight: false,
        supportsDedicatedWorktrees: null,
      );
      return;
    }

    if (!_canApplyLoad(generation: generation, pluginId: pluginId)) return;
    final options = switch (result) {
      NewSessionOptionsLoaded(:final options, :final source) => NewSessionOptionsAvailableState(
        options: options,
        source: source,
      ),
      NewSessionOptionsUnsupported() => const NewSessionOptionsUnsupportedState(),
      NewSessionOptionsUnavailable() => const NewSessionOptionsUnavailableState(),
      NewSessionOptionsLoadFailure(:final error, :final source) => NewSessionOptionsFailureState(
        reason: error.remoteFailureReason,
        source: source,
      ),
      NewSessionOptionsRefreshFailureRetained(:final options) => NewSessionOptionsRefreshFailureRetainedState(
        options: options,
      ),
      NewSessionOptionsRefreshFailureUnavailable() => const NewSessionOptionsRefreshFailureUnavailableState(),
    };
    _emitStateUpdate(
      options: options,
      isPluginDiscoveryInFlight: false,
      supportsDedicatedWorktrees: null,
    );
  }

  NewSessionOptionsLoadState _loadingState({
    required NewSessionOptionsData? previousOptions,
    required NewSessionOptionsSource? source,
  }) => previousOptions == null || source == null
      ? NewSessionOptionsLoadingState(source: source)
      : NewSessionOptionsRefreshingState(options: previousOptions, source: source);

  bool _canApplyLoad({required int generation, required String? pluginId}) {
    if (isClosed || generation != _loadGeneration) return false;
    if (pluginId == null && (state is NewSessionSending || state is NewSessionCreated)) return false;
    return pluginId == null || state.agentModelData?.plugin?.id == pluginId;
  }

  bool get _canEditComposer {
    if (state is NewSessionSending || state is NewSessionCreated) return false;
    final data = state.agentModelData;
    return data != null && !data.isLoading && (data.plugin?.isRoutable ?? false);
  }

  void _emitStateUpdate({
    required NewSessionOptionsLoadState? options,
    required bool? isPluginDiscoveryInFlight,
    required bool? supportsDedicatedWorktrees,
  }) {
    if (isClosed) return;
    final current = state;
    switch (current) {
      case NewSessionIdle():
        emit(
          current.copyWith(
            options: options ?? current.options,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            options: options ?? current.options,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            options: options ?? current.options,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  void _replaceOptionsData({required NewSessionOptionsData options}) {
    final currentOptions = state.agentModelData?.optionsState;
    final source = currentOptions?.source;
    if (source == null) return;
    final next = switch (currentOptions) {
      NewSessionOptionsRefreshFailureRetainedState() => NewSessionOptionsRefreshFailureRetainedState(options: options),
      NewSessionOptionsRefreshingState() => NewSessionOptionsRefreshingState(options: options, source: source),
      NewSessionOptionsLoadingState() ||
      NewSessionOptionsAvailableState() ||
      NewSessionOptionsUnsupportedState() ||
      NewSessionOptionsUnavailableState() ||
      NewSessionOptionsFailureState() ||
      NewSessionOptionsRefreshFailureUnavailableState() ||
      null => NewSessionOptionsAvailableState(options: options, source: source),
    };
    _emitStateUpdate(
      options: next,
      isPluginDiscoveryInFlight: null,
      supportsDedicatedWorktrees: null,
    );
  }

  String? get _selectedPluginId {
    final data = state.agentModelData;
    final pluginId = data?.plugin?.id;
    return data == null || pluginId == null || data.isLoading ? null : pluginId;
  }

  void selectAgent(String agent) {
    if (!_canEditComposer) return;
    final options = state.agentModelData?.optionsState.data;
    if (options == null) return;
    final selected = _newSessionOptionsService.selectAgent(options: options, agent: agent);
    if (selected == null) return;
    _replaceOptionsData(options: selected);
    final pluginId = _selectedPluginId;
    if (pluginId != null) {
      _selectionTracker.recordAgent(projectId: _projectId, pluginId: pluginId, agentName: agent);
    }
  }

  void selectModel({required String providerID, required String modelID}) {
    if (!_canEditComposer) return;
    final options = state.agentModelData?.optionsState.data;
    if (options == null) return;
    final selected = _newSessionOptionsService.selectModel(
      options: options,
      providerId: providerID,
      modelId: modelID,
    );
    if (selected == null) return;
    _replaceOptionsData(options: selected);
    final pluginId = _selectedPluginId;
    if (pluginId != null) {
      _selectionTracker.recordModel(
        projectId: _projectId,
        pluginId: pluginId,
        providerId: providerID,
        modelId: modelID,
      );
    }
  }

  void selectVariant(SessionVariant? variant) {
    if (!_canEditComposer) return;
    final options = state.agentModelData?.optionsState.data;
    if (options == null) return;
    final selected = _newSessionOptionsService.selectVariant(options: options, variant: variant);
    if (selected == null) return;
    _replaceOptionsData(options: selected);
    final pluginId = _selectedPluginId;
    if (pluginId != null) {
      _selectionTracker.recordVariant(
        projectId: _projectId,
        pluginId: pluginId,
        variant: variant == null
            ? const NewSessionDefaultVariantIntent()
            : NewSessionNamedVariantIntent(id: variant.id),
      );
    }
  }

  void stageCommand(CommandInfo command) {
    if (!_canEditComposer) return;
    final options = state.agentModelData?.optionsState.data;
    if (options == null) return;
    final selected = _newSessionOptionsService.stageCommand(options: options, command: command);
    if (selected == null) return;
    _replaceOptionsData(options: selected);
  }

  void clearStagedCommand() {
    final current = state;
    if (current is NewSessionCreated) return;
    if (current is! NewSessionSending && !_canEditComposer) return;
    final options = current.agentModelData?.optionsState.data;
    if (options == null) return;
    _replaceOptionsData(options: _newSessionOptionsService.clearStagedCommand(options: options));
  }

  Future<void> createSession({
    required String text,
    required bool dedicatedWorktree,
    required String? command,
  }) async {
    final current = state;
    if (current is NewSessionSending || current is NewSessionCreated) return;
    final config = current.agentModelData;
    final selectedPlugin = config?.plugin;
    if (config == null || config.isLoading || selectedPlugin == null || !selectedPlugin.isRoutable) return;

    final normalizedCommand = command?.trim();
    final hasCommand = normalizedCommand != null && normalizedCommand.isNotEmpty;
    final trimmed = text.trim();
    if (trimmed.isEmpty && !hasCommand) return;

    final pluginId = selectedPlugin.id;
    final selectionRevisionAtSend = _selectionTracker.currentRevision(
      projectId: _projectId,
      pluginId: pluginId,
    );
    emit(
      NewSessionState.sending(
        availablePlugins: config.plugins,
        selectedPlugin: selectedPlugin,
        options: config.optionsState,
        isPluginDiscoveryInFlight: false,
        supportsDedicatedWorktrees: config.supportsDedicatedWorktrees,
      ),
    );

    final options = config.optionsState.data;
    final selectedAgentModel = options?.selectedAgentModel;
    unawaited(
      _newSessionPluginService.recordSelection(bridgeId: _discoveryBridgeId, plugin: selectedPlugin),
    );
    final selectedVariant = selectedAgentModel?.variant;
    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      pluginId: pluginId,
      text: trimmed,
      agent: options?.selectedAgent,
      providerID: selectedAgentModel?.providerID,
      modelID: selectedAgentModel?.modelID,
      variant: selectedVariant == null ? null : SessionVariant(id: selectedVariant),
      command: normalizedCommand,
      dedicatedWorktree: dedicatedWorktree && config.supportsDedicatedWorktrees,
    );

    if (response case SuccessResponse()) {
      _selectionTracker.clearIfRevision(
        projectId: _projectId,
        pluginId: pluginId,
        revision: selectionRevisionAtSend,
      );
    }

    if (isClosed) return;
    switch (response) {
      case SuccessResponse(:final data):
        emit(NewSessionState.created(session: data));
      case ErrorResponse(:final error):
        loge("New session creation failed", error);
        final latest = state.agentModelData ?? config;
        emit(
          NewSessionState.error(
            reason: error.remoteFailureReason,
            availablePlugins: latest.plugins,
            selectedPlugin: latest.plugin,
            options: latest.optionsState,
            isPluginDiscoveryInFlight: false,
            supportsDedicatedWorktrees: latest.supportsDedicatedWorktrees,
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    ++_loadGeneration;
    ++_projectLoadGeneration;
    await _connectionStatusSubscription.cancel();
    await super.close();
  }
}
