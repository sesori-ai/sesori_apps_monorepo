import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/session/session_service.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../repositories/composer_draft_repository.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/project_repository.dart";
import "../../services/models/new_session_backend_scope.dart";
import "../../services/models/new_session_options_source.dart";
import "../../services/models/new_session_selection_intent.dart";
import "../../services/new_session_options_service.dart";
import "../../services/new_session_plugin_service.dart";
import "../../services/new_session_selection_tracker.dart";
import "../../services/product_analytics_service.dart";
import "new_session_state.dart";

class NewSessionCubit({
  required final ConnectionService _connectionService,
  required final SessionService _sessionService,
  required final NewSessionPluginService _newSessionPluginService,
  required final NewSessionOptionsService _newSessionOptionsService,
  required final ProjectRepository _projectRepository,
  required final NewSessionSelectionTracker _selectionTracker,
  required final ComposerDraftRepository _composerDraftRepository,
  required final ProductAnalyticsService _productAnalyticsService,
  required final String _projectId,
}) extends Cubit<NewSessionState> {
  this
    : super(
        NewSessionState.idle(
          availablePlugins: const [],
          selectedPlugin: null,
          options: const NewSessionOptionsLoadingState(source: null),
          backendScope: _selectionTracker.backendScope.invalidate(),
          isPluginDiscoveryInFlight: false,
          projectWorktreeCapability: NewSessionProjectWorktreeCapability.loading,
        ),
      ) {
    _wasConnected = _connectionService.currentStatus is ConnectionConnected;
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    unawaited(_discoverPlugins());
    unawaited(_loadProjectCapability());
  }

  ComposerDraft _composerDraft = _composerDraftRepository.readForNewSession(projectId: _projectId);
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late bool _wasConnected;
  int _loadGeneration = 0;
  int _projectLoadGeneration = 0;

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (isClosed) return;
    final isConnected = status is ConnectionConnected;
    final reconnected = isConnected && !_wasConnected;
    _wasConnected = isConnected;
    if (!isConnected) {
      final backendScope = state.agentModelData?.backendScope;
      if (backendScope != null) {
        _emitStateUpdate(
          options: null,
          backendScope: backendScope.invalidate(),
          isPluginDiscoveryInFlight: null,
          projectWorktreeCapability: null,
        );
      }
    }
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
      backendScope: null,
      isPluginDiscoveryInFlight: true,
      projectWorktreeCapability: null,
    );
    try {
      final response = await _newSessionPluginService.discover(
        currentSelectedPluginId: beforeDiscovery?.plugin?.id,
        currentSelectionBridgeId: beforeDiscovery?.backendScope.lastIdentifiedBridgeId,
      );
      if (!_canApplyLoad(generation: generation, pluginId: null)) return;

      switch (response) {
        case SuccessResponse(:final data):
          final scopeTransition =
              (beforeDiscovery?.backendScope ?? const NewSessionBackendScope.unverified(lastIdentifiedBridgeId: null))
                  .transitionToDiscovered(bridgeId: data.bridgeId);
          _selectionTracker.applyBackendScopeTransition(transition: scopeTransition);
          final selectedPlugin = data.selected;
          final source = data.optionsSource;
          final previousOptions =
              _canRetainOptions(
                transition: scopeTransition,
                previousData: beforeDiscovery,
                selectedPlugin: selectedPlugin,
                source: source,
              )
              ? beforeDiscovery?.optionsState.data
              : null;
          final canLoad = selectedPlugin?.isRoutable ?? false;
          emit(
            NewSessionState.idle(
              availablePlugins: data.plugins,
              selectedPlugin: selectedPlugin,
              options: canLoad
                  ? _loadingState(previousOptions: previousOptions, source: source)
                  : source == NewSessionOptionsSource.aggregate
                  ? const NewSessionOptionsUnavailableState()
                  : const NewSessionOptionsUnsupportedState(),
              backendScope: scopeTransition.scope,
              isPluginDiscoveryInFlight: false,
              projectWorktreeCapability:
                  state.agentModelData?.projectWorktreeCapability ??
                  beforeDiscovery?.projectWorktreeCapability ??
                  NewSessionProjectWorktreeCapability.loading,
            ),
          );
          if (selectedPlugin != null && canLoad) {
            await _loadOptions(
              pluginId: selectedPlugin.id,
              generation: generation,
              mode: NewSessionOptionsLoadMode.dynamicLoad,
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

  bool _canRetainOptions({
    required NewSessionBackendScopeTransition transition,
    required AgentModelData? previousData,
    required PluginMetadata? selectedPlugin,
    required NewSessionOptionsSource source,
  }) =>
      transition.retainsBackendState &&
      previousData?.plugin?.id != null &&
      selectedPlugin?.id == previousData?.plugin?.id &&
      previousData?.optionsState.source == source;

  void _emitDiscoveryError({required RemoteFailureReason reason}) {
    if (isClosed) return;
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
        backendScope:
            data?.backendScope.invalidate() ?? const NewSessionBackendScope.unverified(lastIdentifiedBridgeId: null),
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: data?.projectWorktreeCapability ?? NewSessionProjectWorktreeCapability.unavailable,
      ),
    );
  }

  Future<void> _loadProjectCapability() async {
    final generation = ++_projectLoadGeneration;
    _emitStateUpdate(
      options: null,
      backendScope: null,
      isPluginDiscoveryInFlight: null,
      projectWorktreeCapability: NewSessionProjectWorktreeCapability.loading,
    );
    try {
      final response = await _projectRepository.getProject(projectId: _projectId);
      if (isClosed || generation != _projectLoadGeneration || state is NewSessionCreated) return;
      switch (response) {
        case SuccessResponse(:final data):
          _emitStateUpdate(
            options: null,
            backendScope: null,
            isPluginDiscoveryInFlight: null,
            projectWorktreeCapability: data.supportsDedicatedWorktrees
                ? NewSessionProjectWorktreeCapability.supported
                : NewSessionProjectWorktreeCapability.unsupported,
          );
        case ErrorResponse(:final error):
          loge("New session: failed to load project $_projectId", error);
          _emitStateUpdate(
            options: null,
            backendScope: null,
            isPluginDiscoveryInFlight: null,
            projectWorktreeCapability: NewSessionProjectWorktreeCapability.unavailable,
          );
      }
    } on Object catch (error, stackTrace) {
      if (isClosed || generation != _projectLoadGeneration) return;
      loge("New session: failed to load project $_projectId", error, stackTrace);
      _emitStateUpdate(
        options: null,
        backendScope: null,
        isPluginDiscoveryInFlight: null,
        projectWorktreeCapability: NewSessionProjectWorktreeCapability.unavailable,
      );
    }
  }

  void selectPlugin({required String pluginId}) {
    final current = state;
    final data = current.agentModelData;
    if (current is NewSessionSending ||
        current is NewSessionCreated ||
        data == null ||
        !data.backendScope.isVerified ||
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
        backendScope: data.backendScope,
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: data.projectWorktreeCapability,
      ),
    );
    unawaited(
      _loadOptions(
        pluginId: pluginId,
        generation: generation,
        mode: NewSessionOptionsLoadMode.dynamicLoad,
        previousOptions: null,
        source: source,
      ),
    );
  }

  Future<void> refreshOptions() async {
    // With no harness known there is nothing to load options for. The user's
    // way forward is to install one on that machine, so the same action goes
    // back to discovery instead — that is where a newly installed harness (or
    // one a failed discovery never got to see) shows up.
    if (needsHarnessDiscovery) {
      await _discoverPlugins();
      return;
    }

    if (state.agentModelData?.projectWorktreeCapability == NewSessionProjectWorktreeCapability.unavailable) {
      await _loadProjectCapability();
      return;
    }

    final current = state;
    final data = current.agentModelData;
    final plugin = data?.plugin;
    final source = data?.optionsState.source;
    if (current is NewSessionSending ||
        current is NewSessionCreated ||
        !(data?.backendScope.isVerified ?? false) ||
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
      backendScope: null,
      isPluginDiscoveryInFlight: false,
      projectWorktreeCapability: null,
    );
    await _loadOptions(
      pluginId: plugin.id,
      generation: generation,
      mode: NewSessionOptionsLoadMode.forcedRefresh,
      previousOptions: previousOptions,
      source: source,
    );
  }

  Future<void> _loadOptions({
    required String pluginId,
    required int generation,
    required NewSessionOptionsLoadMode mode,
    required NewSessionOptionsData? previousOptions,
    required NewSessionOptionsSource source,
  }) async {
    final NewSessionOptionsLoadResult result;
    try {
      result = await _newSessionOptionsService.load(
        projectId: _projectId,
        pluginId: pluginId,
        source: source,
        mode: mode,
        restoredSelection: _selectionTracker.read(projectId: _projectId, pluginId: pluginId),
        previousOptions: previousOptions,
      );
    } on Object catch (error, stackTrace) {
      if (!_canApplyLoad(generation: generation, pluginId: pluginId)) return;
      loge(
        "New session: failed to load options for plugin $pluginId "
        "(source: ${source.name}, mode: ${mode.name})",
        error,
        stackTrace,
      );
      _emitStateUpdate(
        options: previousOptions != null
            ? NewSessionOptionsFailureRetainedState(options: previousOptions, source: source)
            : NewSessionOptionsFailureState(reason: RemoteFailureReason.unknown, source: source),
        backendScope: null,
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: null,
      );
      return;
    }

    if (!_canApplyLoad(generation: generation, pluginId: pluginId)) return;
    // The bridge answers these with an opaque error code rather than an
    // exception, so without this the screen renders a failure no log explains.
    if (result
        case NewSessionOptionsLoadFailureUnavailable() ||
            NewSessionOptionsRefreshFailureUnavailable() ||
            NewSessionOptionsFailureUnavailable()) {
      logw(
        "New session: options unavailable for plugin $pluginId "
        "(source: ${source.name}, mode: ${mode.name}, result: ${result.runtimeType.toString()})",
      );
    }
    final options = switch (result) {
      NewSessionOptionsLoaded(:final options, :final source) => NewSessionOptionsAvailableState(
        options: options,
        source: source,
      ),
      NewSessionOptionsUnsupported() => const NewSessionOptionsUnsupportedState(),
      NewSessionOptionsUnavailable() => const NewSessionOptionsUnavailableState(),
      NewSessionOptionsLoadFailureUnavailable() => const NewSessionOptionsLoadFailureUnavailableState(),
      NewSessionOptionsFailureRetained(:final options, :final source) => NewSessionOptionsFailureRetainedState(
        options: options,
        source: source,
      ),
      NewSessionOptionsFailureUnavailable(:final error, :final source) => NewSessionOptionsFailureState(
        reason: error.remoteFailureReason,
        source: source,
      ),
      NewSessionOptionsRefreshFailureUnavailable() => const NewSessionOptionsRefreshFailureUnavailableState(),
    };
    _emitStateUpdate(
      options: options,
      backendScope: null,
      isPluginDiscoveryInFlight: false,
      projectWorktreeCapability: null,
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

  /// Whether the screen has no harness to work with — the bridge answered with
  /// none, or discovery failed before it could answer. Either way the only load
  /// worth repeating is discovery itself, not options for a harness that does
  /// not exist. Held back while discovery is in flight, which the screen is
  /// already reporting on its own.
  bool get needsHarnessDiscovery {
    if (state is NewSessionSending || state is NewSessionCreated) return false;
    final data = state.agentModelData;
    return data != null && data.plugins.isEmpty && !data.isPluginDiscoveryInFlight;
  }

  /// Whether the bridge itself answered that it runs no harness. Only then may
  /// the screen state that as fact — after a failed discovery the error is the
  /// honest explanation, and retrying is still the way forward.
  bool get hasNoHarnesses => needsHarnessDiscovery && (state.agentModelData?.backendScope.isVerified ?? false);

  bool get canRefreshOptions =>
      needsHarnessDiscovery ||
      state.agentModelData?.projectWorktreeCapability == NewSessionProjectWorktreeCapability.unavailable ||
      ((state.agentModelData?.backendScope.isVerified ?? false) && _canEditComposer);

  bool get canCreateSession {
    final data = state.agentModelData;
    return (data?.backendScope.isVerified ?? false) &&
        data?.projectWorktreeCapability != NewSessionProjectWorktreeCapability.unavailable &&
        _canEditComposer;
  }

  void _emitStateUpdate({
    required NewSessionOptionsLoadState? options,
    required NewSessionBackendScope? backendScope,
    required bool? isPluginDiscoveryInFlight,
    required NewSessionProjectWorktreeCapability? projectWorktreeCapability,
  }) {
    if (isClosed) return;
    final current = state;
    switch (current) {
      case NewSessionIdle():
        emit(
          current.copyWith(
            options: options ?? current.options,
            backendScope: backendScope ?? current.backendScope,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            projectWorktreeCapability: projectWorktreeCapability ?? current.projectWorktreeCapability,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            options: options ?? current.options,
            backendScope: backendScope ?? current.backendScope,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            projectWorktreeCapability: projectWorktreeCapability ?? current.projectWorktreeCapability,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            options: options ?? current.options,
            backendScope: backendScope ?? current.backendScope,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            projectWorktreeCapability: projectWorktreeCapability ?? current.projectWorktreeCapability,
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
      NewSessionOptionsFailureRetainedState() => NewSessionOptionsFailureRetainedState(
        options: options,
        source: source,
      ),
      NewSessionOptionsRefreshingState() => NewSessionOptionsRefreshingState(options: options, source: source),
      NewSessionOptionsLoadingState() ||
      NewSessionOptionsAvailableState() ||
      NewSessionOptionsUnsupportedState() ||
      NewSessionOptionsUnavailableState() ||
      NewSessionOptionsLoadFailureUnavailableState() ||
      NewSessionOptionsFailureState() ||
      NewSessionOptionsRefreshFailureUnavailableState() ||
      null => NewSessionOptionsAvailableState(options: options, source: source),
    };
    _emitStateUpdate(
      options: next,
      backendScope: null,
      isPluginDiscoveryInFlight: null,
      projectWorktreeCapability: null,
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
    required List<ComposerAttachment> attachments,
  }) async {
    final current = state;
    if (current is NewSessionSending || current is NewSessionCreated) return;
    final config = current.agentModelData;
    final selectedPlugin = config?.plugin;
    if (config == null ||
        !config.backendScope.isVerified ||
        config.isLoading ||
        config.projectWorktreeCapability == NewSessionProjectWorktreeCapability.unavailable ||
        selectedPlugin == null ||
        !selectedPlugin.isRoutable) {
      return;
    }

    final normalizedCommand = command?.trim();
    final hasCommand = normalizedCommand != null && normalizedCommand.isNotEmpty;
    final trimmed = text.trim();
    if (trimmed.isEmpty && !hasCommand && attachments.isEmpty) return;

    // The bridge's command paths carry only the text part, so sending this
    // combination would drop the images without telling anyone. Refuse it at
    // the seam that formats the wire payload, not only in the composer.
    if (hasCommand && attachments.isNotEmpty) {
      logw("Refused a /$normalizedCommand submission carrying ${attachments.length} attachment(s)");
      return;
    }

    // Hold the declared capability line at the wire seam too, so stale or
    // synthetic callers cannot submit images to a plugin that would drop them.
    if (attachments.isNotEmpty && !selectedPlugin.supportsPromptAttachments) {
      logw("Refused ${attachments.length} attachment(s) for plugin ${selectedPlugin.id}");
      return;
    }

    final analyticsSubmission = hasCommand
        ? const AnalyticsSubmission.command()
        : AnalyticsSubmission.text(inputMode: _analyticsInputMode(inputMode));
    final usesDedicatedWorktree =
        dedicatedWorktree && config.projectWorktreeCapability == NewSessionProjectWorktreeCapability.supported;
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
        backendScope: config.backendScope,
        isPluginDiscoveryInFlight: false,
        projectWorktreeCapability: config.projectWorktreeCapability,
      ),
    );

    final options = config.optionsState.data;
    final selectedAgentModel = options?.selectedAgentModel;
    unawaited(
      _newSessionPluginService.recordSelection(
        bridgeId: config.backendScope.identifiedBridgeId,
        plugin: selectedPlugin,
      ),
    );
    final selectedVariant = selectedAgentModel?.variant;
    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      pluginId: pluginId,
      text: trimmed,
      attachments: attachments,
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
            backendScope: latest.backendScope,
            isPluginDiscoveryInFlight: false,
            projectWorktreeCapability: latest.projectWorktreeCapability,
          ),
        );
        if (!latest.backendScope.isVerified && _wasConnected) {
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
