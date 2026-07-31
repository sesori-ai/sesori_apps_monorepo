import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/session/session_service.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../foundation/models/composer/composer_draft.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../repositories/composer_draft_repository.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/project_repository.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/models/new_session_selection_intent.dart";
import "../../services/new_session_options_service.dart";
import "../../services/new_session_plugin_service.dart";
import "../../services/new_session_selection_tracker.dart";
import "../../services/product_analytics_service.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  NewSessionCubit({
    required ConnectionService connectionService,
    required SessionService sessionService,
    required NewSessionPluginService newSessionPluginService,
    required NewSessionOptionsService newSessionOptionsService,
    required ProjectRepository projectRepository,
    required NewSessionSelectionTracker selectionTracker,
    required ComposerDraftRepository composerDraftRepository,
    required ProductAnalyticsService productAnalyticsService,
    required String projectId,
    required bool? initialSupportsDedicatedWorktrees,
  }) : _connectionService = connectionService,
       _sessionService = sessionService,
       _newSessionPluginService = newSessionPluginService,
       _newSessionOptionsService = newSessionOptionsService,
       _projectRepository = projectRepository,
       _selectionTracker = selectionTracker,
       _composerDraftRepository = composerDraftRepository,
       _productAnalyticsService = productAnalyticsService,
       _projectId = projectId,
       _composerDraft = composerDraftRepository.readForNewSession(projectId: projectId),
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
  final ComposerDraftRepository _composerDraftRepository;
  final ProductAnalyticsService _productAnalyticsService;
  final String _projectId;
  ComposerDraft _composerDraft;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late bool _wasConnected;
  int _loadGeneration = 0;
  int _projectLoadGeneration = 0;
  String? _discoveryBridgeId;
  bool _hasDiscoveryAffinity = false;

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (isClosed) return;
    final isConnected = status is ConnectionConnected;
    final reconnected = isConnected && !_wasConnected;
    _wasConnected = isConnected;
    if (!isConnected) _hasDiscoveryAffinity = false;
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
          _hasDiscoveryAffinity = true;
          _selectionTracker.establishBridgeScope(bridgeId: data.bridgeId);
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
    // Retained options still belong to the last successful bridge scope, but a
    // failed discovery cannot prove that the current connection has affinity
    // with that bridge.
    _hasDiscoveryAffinity = false;
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
        !_hasDiscoveryAffinity ||
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
      loge(
        "New session: failed to load options for plugin $pluginId "
        "(source: ${source.name}, refresh: ${refresh.toString()})",
        error,
        stackTrace,
      );
      _emitStateUpdate(
        options: refresh && previousOptions != null
            ? NewSessionOptionsRefreshFailureRetainedState(options: previousOptions, source: source)
            : NewSessionOptionsFailureState(reason: RemoteFailureReason.unknown, source: source),
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
      NewSessionOptionsLoadFailure(:final error, :final source) => refresh && previousOptions != null
          ? NewSessionOptionsRefreshFailureRetainedState(options: previousOptions, source: source)
          : NewSessionOptionsFailureState(reason: error.remoteFailureReason, source: source),
      NewSessionOptionsRefreshFailureRetained(:final options) => NewSessionOptionsRefreshFailureRetainedState(
        options: options,
        source: source,
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

  bool get canRefreshOptions => _hasDiscoveryAffinity && _canEditComposer;

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
      NewSessionOptionsRefreshFailureRetainedState() => NewSessionOptionsRefreshFailureRetainedState(
        options: options,
        source: source,
      ),
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
    final pluginId = _selectedPluginId;
    final selectionIntent = pluginId == null ? null : _selectionTracker.read(projectId: _projectId, pluginId: pluginId);
    final selected = _newSessionOptionsService.selectAgent(
      options: options,
      agent: agent,
      selectionIntent: selectionIntent,
    );
    if (selected == null) return;
    _replaceOptionsData(options: selected);
    if (pluginId != null) {
      _selectionTracker.recordAgent(projectId: _projectId, pluginId: pluginId, agentName: agent);
    }
  }

  void selectModel({required String providerID, required String modelID}) {
    if (!_canEditComposer) return;
    final options = state.agentModelData?.optionsState.data;
    if (options == null) return;
    final pluginId = _selectedPluginId;
    final variantIntent = pluginId == null
        ? null
        : _selectionTracker.read(projectId: _projectId, pluginId: pluginId)?.variant;
    final selected = _newSessionOptionsService.selectModel(
      options: options,
      providerId: providerID,
      modelId: modelID,
      variantIntent: variantIntent,
    );
    if (selected == null) return;
    _replaceOptionsData(options: selected);
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
    required ComposerInputMode inputMode,
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
    final analyticsSubmission = hasCommand
        ? const AnalyticsSubmission.command()
        : AnalyticsSubmission.text(inputMode: _analyticsInputMode(inputMode));
    final usesDedicatedWorktree = dedicatedWorktree && config.supportsDedicatedWorktrees;
    final workspaceKind = usesDedicatedWorktree
        ? AnalyticsWorkspaceKind.dedicatedWorktree
        : AnalyticsWorkspaceKind.project;

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
      _newSessionPluginService.recordSelection(
        bridgeId: _hasDiscoveryAffinity ? _discoveryBridgeId : null,
        plugin: selectedPlugin,
      ),
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
      dedicatedWorktree: usesDedicatedWorktree,
    );

    switch (response) {
      case SuccessResponse():
        _selectionTracker.clearIfRevision(
          projectId: _projectId,
          pluginId: pluginId,
          revision: selectionRevisionAtSend,
        );
        _reportProductEvent(
          event: ProductAnalyticsEvent.sessionCreatedWithMessage(
            submission: analyticsSubmission,
            workspaceKind: workspaceKind,
          ),
        );
      case ErrorResponse(:final error):
        _reportProductEvent(
          event: ProductAnalyticsEvent.sessionCreationFailed(
            failureReason: _analyticsFailureReason(error.remoteFailureReason),
            workspaceKind: workspaceKind,
          ),
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
        if (!_hasDiscoveryAffinity && _wasConnected) {
          unawaited(_discoverPlugins());
          unawaited(_loadProjectCapability());
        }
    }
  }

  ComposerDraft get composerDraft => _composerDraft;

  void saveComposerDraft({required ComposerDraft draft}) {
    _composerDraft = draft;
    _composerDraftRepository.saveForNewSession(projectId: _projectId, draft: draft);
  }

  void clearComposerDraft() {
    _composerDraft = ComposerDraft.typed(text: "");
    _composerDraftRepository.clearForNewSession(projectId: _projectId);
  }

  void reportVoiceTranscriptionCompleted() {
    _reportProductEvent(event: const ProductAnalyticsEvent.voiceTranscriptionCompleted());
  }

  AnalyticsInputMode _analyticsInputMode(ComposerInputMode inputMode) => switch (inputMode) {
    ComposerInputMode.typed => AnalyticsInputMode.typed,
    ComposerInputMode.voiceAssisted => AnalyticsInputMode.voiceAssisted,
  };

  AnalyticsSessionCreationFailureReason _analyticsFailureReason(RemoteFailureReason reason) => switch (reason) {
    RemoteFailureReason.notAuthenticated => AnalyticsSessionCreationFailureReason.notAuthenticated,
    RemoteFailureReason.serverRejected => AnalyticsSessionCreationFailureReason.serverRejected,
    RemoteFailureReason.networkDown => AnalyticsSessionCreationFailureReason.networkDown,
    RemoteFailureReason.badResponse => AnalyticsSessionCreationFailureReason.badResponse,
    RemoteFailureReason.unknown => AnalyticsSessionCreationFailureReason.unknown,
  };

  void _reportProductEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver new-session outcome analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report new-session outcome analytics event", error, stackTrace);
          }),
    );
  }

  @override
  Future<void> close() async {
    ++_loadGeneration;
    ++_projectLoadGeneration;
    await _connectionStatusSubscription.cancel();
    await super.close();
  }
}
