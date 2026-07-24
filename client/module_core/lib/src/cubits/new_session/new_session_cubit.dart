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
import "../../repositories/plugin_repository.dart";
import "../../repositories/project_repository.dart";
import "../../services/new_session_selection_tracker.dart";
import "../../utils/model_filter/default_model_selector.dart";
import "new_session_state.dart";

class NewSessionCubit extends Cubit<NewSessionState> {
  final ConnectionService _connectionService;
  final SessionService _sessionService;
  final PluginRepository _pluginRepository;
  final ProjectRepository _projectRepository;
  final NewSessionSelectionTracker _selectionTracker;
  final String _projectId;
  late final StreamSubscription<ConnectionStatus> _connectionStatusSubscription;
  late bool _wasConnected;
  int _loadGeneration = 0;
  int _projectLoadGeneration = 0;

  static const _defaultModelSelector = DefaultModelSelector();

  NewSessionCubit({
    required ConnectionService connectionService,
    required SessionService sessionService,
    required PluginRepository pluginRepository,
    required ProjectRepository projectRepository,
    required NewSessionSelectionTracker selectionTracker,
    required String projectId,
    required bool? initialSupportsDedicatedWorktrees,
  }) : _connectionService = connectionService,
       _sessionService = sessionService,
       _pluginRepository = pluginRepository,
       _projectRepository = projectRepository,
       _selectionTracker = selectionTracker,
       _projectId = projectId,
       super(
         NewSessionState.idle(
           availablePlugins: const [],
           selectedPlugin: null,
           isComposerDataLoading: true,
           isPluginDiscoveryInFlight: false,
           availableAgents: [],
           availableProviders: [],
           availableCommands: [],
           selectedAgent: null,
           selectedAgentModel: null,
           stagedCommand: null,
           availableVariants: [],
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
    _emitAgentModelUpdate(
      availableAgents: null,
      availableProviders: null,
      availableCommands: null,
      selectedAgent: null,
      selectedAgentModel: null,
      isComposerDataLoading: true,
      isPluginDiscoveryInFlight: true,
      supportsDedicatedWorktrees: null,
    );
    try {
      final response = await _pluginRepository.listPlugins();
      if (!_canApplyLoad(generation: generation, pluginId: null)) return;

      switch (response) {
        case SuccessResponse(:final data):
          final plugins = data.plugins;
          final currentData = state.agentModelData;
          final currentPluginId = currentData?.plugin?.id;
          final currentPlugin = currentPluginId == null
              ? null
              : plugins.firstWhereOrNull((plugin) => plugin.id == currentPluginId && plugin.isRoutable);
          final selectedPlugin = currentPlugin ?? plugins.where((plugin) => plugin.isDefault).singleOrNull;
          final canLoad = selectedPlugin?.isRoutable ?? false;
          final isSamePlugin = currentPluginId != null && selectedPlugin?.id == currentPluginId;
          final stagedCommand = isSamePlugin ? currentData?.stagedCommand : null;
          emit(
            NewSessionState.idle(
              availablePlugins: plugins,
              selectedPlugin: selectedPlugin,
              isComposerDataLoading: canLoad,
              isPluginDiscoveryInFlight: false,
              availableAgents: const [],
              availableProviders: const [],
              availableCommands: isSamePlugin ? currentData?.commands ?? const [] : const [],
              selectedAgent: null,
              selectedAgentModel: null,
              stagedCommand: stagedCommand,
              availableVariants: const [],
              supportsDedicatedWorktrees: currentData?.supportsDedicatedWorktrees ?? false,
            ),
          );
          if (selectedPlugin != null && canLoad) {
            await _loadComposerData(
              pluginId: selectedPlugin.id,
              generation: generation,
              providerFailureFallback: isSamePlugin ? currentData?.providers ?? const [] : const [],
              modelFailureFallback: isSamePlugin ? currentData?.agentModel : null,
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
    final data = state.agentModelData;
    emit(
      NewSessionState.error(
        reason: reason,
        availablePlugins: data?.plugins ?? const [],
        selectedPlugin: data?.plugin,
        isComposerDataLoading: false,
        isPluginDiscoveryInFlight: false,
        availableAgents: data?.agents ?? const [],
        availableProviders: data?.providers ?? const [],
        availableCommands: data?.commands ?? const [],
        selectedAgent: data?.agent,
        selectedAgentModel: data?.agentModel,
        stagedCommand: data?.stagedCommand,
        availableVariants: data?.availableVariants ?? const [],
        supportsDedicatedWorktrees: data?.supportsDedicatedWorktrees ?? false,
      ),
    );
  }

  Future<void> _loadProjectCapability() async {
    final generation = ++_projectLoadGeneration;
    try {
      final response = await _projectRepository.getProject(projectId: _projectId);
      if (isClosed || generation != _projectLoadGeneration || state is NewSessionCreated) return;
      final bool supportsDedicatedWorktrees;
      switch (response) {
        case SuccessResponse(:final data):
          supportsDedicatedWorktrees = data.supportsDedicatedWorktrees;
        case ErrorResponse(:final error):
          loge("New session: failed to load project $_projectId", error);
          return;
      }
      if (state.agentModelData?.supportsDedicatedWorktrees == supportsDedicatedWorktrees) return;
      _emitAgentModelUpdate(
        availableAgents: null,
        availableProviders: null,
        availableCommands: null,
        selectedAgent: null,
        selectedAgentModel: null,
        isComposerDataLoading: null,
        isPluginDiscoveryInFlight: null,
        supportsDedicatedWorktrees: supportsDedicatedWorktrees,
      );
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
    if (selectedPlugin == null || !selectedPlugin.isRoutable) return;

    final generation = ++_loadGeneration;
    emit(
      NewSessionState.idle(
        availablePlugins: data.plugins,
        selectedPlugin: selectedPlugin,
        isComposerDataLoading: true,
        isPluginDiscoveryInFlight: false,
        availableAgents: const [],
        availableProviders: const [],
        availableCommands: const [],
        selectedAgent: null,
        selectedAgentModel: null,
        stagedCommand: null,
        availableVariants: const [],
        supportsDedicatedWorktrees: data.supportsDedicatedWorktrees,
      ),
    );
    _loadComposerData(
      pluginId: pluginId,
      generation: generation,
      providerFailureFallback: const [],
      modelFailureFallback: null,
    );
  }

  Future<void> _loadComposerData({
    required String pluginId,
    required int generation,
    required List<ProviderInfo> providerFailureFallback,
    required AgentModel? modelFailureFallback,
  }) async {
    final (agents, loadedProviders, commands) = await (
      _loadAgents(pluginId: pluginId),
      _loadProviders(pluginId: pluginId),
      _loadCommands(pluginId: pluginId),
    ).wait;

    if (!_canApplyLoad(generation: generation, pluginId: pluginId)) return;
    final providers = loadedProviders ?? providerFailureFallback;

    final defaultAgent = agents.firstOrNull?.name;
    final agentModel = agents.firstOrNull?.model;
    final AgentModel? defaultAgentModel;
    if (agentModel != null) {
      defaultAgentModel = agentModel;
    } else {
      AgentModel? pickedModel;
      for (final provider in providers) {
        final picked = _defaultModelSelector.pickFromProvider(
          models: provider.models,
          defaultModelID: provider.defaultModelID,
        );
        if (picked != null) {
          pickedModel = AgentModel(providerID: provider.id, modelID: picked.id, variant: null);
          break;
        }
      }
      defaultAgentModel = pickedModel;
    }

    final (:selectedAgent, selectedAgentModel: resolvedAgentModel) = _resolveInitialSelection(
      pluginId: pluginId,
      defaultAgent: defaultAgent,
      defaultAgentModel: defaultAgentModel,
      agents: agents,
      providers: providers,
    );
    final selectedAgentModel = loadedProviders == null ? modelFailureFallback : resolvedAgentModel;

    _emitAgentModelUpdate(
      availableAgents: agents,
      availableProviders: providers,
      availableCommands: commands,
      selectedAgent: selectedAgent,
      selectedAgentModel: selectedAgentModel,
      isComposerDataLoading: false,
      isPluginDiscoveryInFlight: false,
      supportsDedicatedWorktrees: null,
    );
  }

  Future<List<AgentInfo>> _loadAgents({required String pluginId}) async {
    try {
      final response = await _sessionService.listAgents(projectId: _projectId, pluginId: pluginId);
      _logComposerDataError(resource: "agents", pluginId: pluginId, response: response);
      return switch (response) {
        SuccessResponse(:final data) =>
          data.agents.where((agent) => !agent.hidden && agent.mode != AgentMode.subagent).toList(),
        ErrorResponse() => <AgentInfo>[],
      };
    } on Object catch (error, stackTrace) {
      loge("New session: failed to load agents for project $_projectId and plugin $pluginId", error, stackTrace);
      return <AgentInfo>[];
    }
  }

  Future<List<ProviderInfo>?> _loadProviders({required String pluginId}) async {
    try {
      final response = await _sessionService.listProviders(projectId: _projectId, pluginId: pluginId);
      _logComposerDataError(resource: "providers", pluginId: pluginId, response: response);
      return switch (response) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => null,
      };
    } on Object catch (error, stackTrace) {
      loge("New session: failed to load providers for project $_projectId and plugin $pluginId", error, stackTrace);
      return null;
    }
  }

  Future<List<CommandInfo>?> _loadCommands({required String pluginId}) async {
    try {
      final response = await _sessionService.listCommands(projectId: _projectId, pluginId: pluginId);
      _logComposerDataError(resource: "commands", pluginId: pluginId, response: response);
      return switch (response) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => null,
      };
    } on Object catch (error, stackTrace) {
      loge("New session: failed to load commands for project $_projectId and plugin $pluginId", error, stackTrace);
      return null;
    }
  }

  bool _canApplyLoad({required int generation, required String? pluginId}) {
    if (isClosed || generation != _loadGeneration) return false;
    if (pluginId == null && (state is NewSessionSending || state is NewSessionCreated)) return false;
    return pluginId == null || state.agentModelData?.plugin?.id == pluginId;
  }

  void _logComposerDataError<T>({
    required String resource,
    required String pluginId,
    required ApiResponse<T> response,
  }) {
    if (response case ErrorResponse(:final error)) {
      loge("New session: failed to load $resource for project $_projectId and plugin $pluginId", error);
    }
  }

  void _emitAgentModelUpdate({
    required List<AgentInfo>? availableAgents,
    required List<ProviderInfo>? availableProviders,
    required List<CommandInfo>? availableCommands,
    required String? selectedAgent,
    required AgentModel? selectedAgentModel,
    required bool? isComposerDataLoading,
    required bool? isPluginDiscoveryInFlight,
    required bool? supportsDedicatedWorktrees,
  }) {
    if (isClosed) return;
    final current = state;
    final data = current.agentModelData;
    if (data == null) return;
    final stagedCommand = data.stagedCommand;
    final revalidatedStagedCommand = availableCommands == null || stagedCommand == null
        ? stagedCommand
        : availableCommands.firstWhereOrNull((command) => command.name == stagedCommand.name);
    final derivedVariants = _deriveAvailableVariants(
      providers: availableProviders ?? data.providers,
      model: selectedAgentModel ?? data.agentModel,
    );
    switch (current) {
      case NewSessionIdle():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            stagedCommand: revalidatedStagedCommand,
            availableVariants: derivedVariants,
            isComposerDataLoading: isComposerDataLoading ?? current.isComposerDataLoading,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionSending():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            stagedCommand: revalidatedStagedCommand,
            availableVariants: derivedVariants,
            isComposerDataLoading: isComposerDataLoading ?? current.isComposerDataLoading,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionError():
        emit(
          current.copyWith(
            availableAgents: availableAgents ?? current.availableAgents,
            availableProviders: availableProviders ?? current.availableProviders,
            availableCommands: availableCommands ?? current.availableCommands,
            selectedAgent: selectedAgent ?? current.selectedAgent,
            selectedAgentModel: selectedAgentModel ?? current.selectedAgentModel,
            stagedCommand: revalidatedStagedCommand,
            availableVariants: derivedVariants,
            isComposerDataLoading: isComposerDataLoading ?? current.isComposerDataLoading,
            isPluginDiscoveryInFlight: isPluginDiscoveryInFlight ?? current.isPluginDiscoveryInFlight,
            supportsDedicatedWorktrees: supportsDedicatedWorktrees ?? current.supportsDedicatedWorktrees,
          ),
        );
      case NewSessionCreated():
        break;
    }
  }

  List<SessionVariant> _deriveAvailableVariants({
    required List<ProviderInfo> providers,
    required AgentModel? model,
  }) {
    final providerID = model?.providerID;
    final modelID = model?.modelID;
    final provider = providerID != null ? providers.firstWhereOrNull((item) => item.id == providerID) : null;
    final providerModel = provider?.models[modelID];
    return providerModel?.variants
            .where((variant) => variant != "none")
            .map((variant) => SessionVariant(id: variant))
            .toList() ??
        [];
  }

  ({String? selectedAgent, AgentModel? selectedAgentModel}) _resolveInitialSelection({
    required String pluginId,
    required String? defaultAgent,
    required AgentModel? defaultAgentModel,
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
  }) {
    final saved = _selectionTracker.read(projectId: _projectId, pluginId: pluginId);
    if (saved == null) {
      return (selectedAgent: defaultAgent, selectedAgentModel: defaultAgentModel);
    }

    final savedAgent = saved.agent;
    final selectedAgent = savedAgent != null && agents.any((agent) => agent.name == savedAgent)
        ? savedAgent
        : defaultAgent;

    final savedModel = saved.agentModel;
    AgentModel? selectedAgentModel = defaultAgentModel;
    if (savedModel != null && _modelIsAvailable(providers: providers, model: savedModel)) {
      final availableVariants = _deriveAvailableVariants(providers: providers, model: savedModel);
      final variant = savedModel.variant;
      final validVariant = variant != null && availableVariants.any((item) => item.id == variant) ? variant : null;
      selectedAgentModel = savedModel.copyWith(variant: validVariant);
    }

    return (selectedAgent: selectedAgent, selectedAgentModel: selectedAgentModel);
  }

  bool _modelIsAvailable({required List<ProviderInfo> providers, required AgentModel model}) {
    final providerModel = providers.firstWhereOrNull((item) => item.id == model.providerID)?.models[model.modelID];
    return providerModel != null && providerModel.isAvailable;
  }

  bool get _canEditComposer {
    if (state is NewSessionSending || state is NewSessionCreated) return false;
    final data = state.agentModelData;
    return data != null && !data.isLoading && (data.plugin?.isRoutable ?? false);
  }

  void _persistSelection() {
    final data = state.agentModelData;
    final pluginId = data?.plugin?.id;
    if (data == null || pluginId == null || data.isLoading) return;
    _selectionTracker.write(
      projectId: _projectId,
      pluginId: pluginId,
      agent: data.agent,
      agentModel: data.agentModel,
    );
  }

  void selectAgent(String agent) {
    if (!_canEditComposer) return;
    final current = state;
    final agentInfo = switch (current) {
      NewSessionIdle() => current.availableAgents.firstWhereOrNull((item) => item.name == agent),
      NewSessionError() => current.availableAgents.firstWhereOrNull((item) => item.name == agent),
      NewSessionSending() || NewSessionCreated() => null,
    };
    if (agentInfo == null) return;
    _emitAgentModelUpdate(
      selectedAgent: agent,
      selectedAgentModel: agentInfo.model,
      availableAgents: null,
      availableCommands: null,
      availableProviders: null,
      isComposerDataLoading: null,
      isPluginDiscoveryInFlight: null,
      supportsDedicatedWorktrees: null, // no change
    );
    _persistSelection();
  }

  void selectVariant(SessionVariant? variant) {
    if (!_canEditComposer) return;
    final current = state;
    final availableVariants = current.agentModelData?.availableVariants ?? const [];
    if (variant != null && !availableVariants.any((available) => available.id == variant.id)) return;
    switch (current) {
      case NewSessionIdle():
        final agentModel = current.selectedAgentModel;
        if (agentModel == null) return;
        emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
      case NewSessionError():
        final agentModel = current.selectedAgentModel;
        if (agentModel == null) return;
        emit(current.copyWith(selectedAgentModel: agentModel.copyWith(variant: variant?.id)));
      case NewSessionSending() || NewSessionCreated():
        return;
    }
    _persistSelection();
  }

  void stageCommand(CommandInfo command) {
    if (!_canEditComposer) return;
    final current = state;
    final currentCommand = current.agentModelData?.commands.firstWhereOrNull((available) => available == command);
    if (currentCommand == null) return;
    switch (current) {
      case NewSessionIdle():
        emit(current.copyWith(stagedCommand: currentCommand));
      case NewSessionError():
        emit(current.copyWith(stagedCommand: currentCommand));
      case NewSessionSending() || NewSessionCreated():
        break;
    }
  }

  void clearStagedCommand() {
    final current = state;
    switch (current) {
      case NewSessionIdle():
        if (!_canEditComposer) return;
        emit(current.copyWith(stagedCommand: null));
      case NewSessionError():
        if (!_canEditComposer) return;
        emit(current.copyWith(stagedCommand: null));
      case NewSessionSending():
        emit(current.copyWith(stagedCommand: null));
      case NewSessionCreated():
        break;
    }
  }

  void selectModel({required String providerID, required String modelID}) {
    if (!_canEditComposer) return;
    final current = state.agentModelData;
    if (current == null) return;
    final selectedModel = AgentModel(providerID: providerID, modelID: modelID, variant: null);
    if (!_modelIsAvailable(providers: current.providers, model: selectedModel)) return;

    final availableVariants = _deriveAvailableVariants(
      providers: current.providers,
      model: selectedModel,
    );
    final agentModel = _resolveAgentModel(
      agents: current.agents,
      providerID: providerID,
      modelID: modelID,
    );
    final previousVariant = current.agentModel?.variant;
    final variant = previousVariant != null && availableVariants.any((item) => item.id == previousVariant)
        ? previousVariant
        : agentModel?.variant;

    _emitAgentModelUpdate(
      selectedAgentModel:
          agentModel?.copyWith(variant: variant) ??
          AgentModel(providerID: providerID, modelID: modelID, variant: variant),
      selectedAgent: null,
      availableAgents: null,
      availableCommands: null,
      availableProviders: null,
      isComposerDataLoading: null,
      isPluginDiscoveryInFlight: null,
      supportsDedicatedWorktrees: null, // no change
    );
    _persistSelection();
  }

  AgentModel? _resolveAgentModel({
    required List<AgentInfo> agents,
    required String providerID,
    required String modelID,
  }) {
    final agent = agents.firstWhereOrNull(
      (item) => item.model?.providerID == providerID && item.model?.modelID == modelID,
    );
    return agent?.model ?? AgentModel(providerID: providerID, modelID: modelID, variant: null);
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
        isComposerDataLoading: false,
        isPluginDiscoveryInFlight: false,
        availableAgents: config.agents,
        availableProviders: config.providers,
        availableCommands: config.commands,
        selectedAgent: config.agent,
        selectedAgentModel: config.agentModel,
        stagedCommand: config.stagedCommand,
        availableVariants: config.availableVariants,
        supportsDedicatedWorktrees: config.supportsDedicatedWorktrees,
      ),
    );

    final variantId = config.agentModel?.variant;
    final response = await _sessionService.createSessionWithMessage(
      projectId: _projectId,
      pluginId: pluginId,
      text: trimmed,
      agent: config.agent,
      providerID: config.agentModel?.providerID,
      modelID: config.agentModel?.modelID,
      variant: variantId == null ? null : SessionVariant(id: variantId),
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
            isComposerDataLoading: latest.isLoading,
            isPluginDiscoveryInFlight: false,
            availableAgents: latest.agents,
            availableProviders: latest.providers,
            availableCommands: latest.commands,
            selectedAgent: latest.agent,
            selectedAgentModel: latest.agentModel,
            stagedCommand: latest.stagedCommand,
            availableVariants: latest.availableVariants,
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
