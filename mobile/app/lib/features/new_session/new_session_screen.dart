import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
import "../../core/widgets/agent_picker_sheet.dart";
import "../../core/widgets/model_picker_sheet.dart";
import "../../core/widgets/variant_picker_sheet.dart";
import "../session_detail/widgets/prompt_input.dart";
import "new_session_loading_overlay.dart";

class NewSessionScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const NewSessionScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSessionCubit(
        sessionService: getIt<SessionService>(),
        projectId: projectId,
      ),
      child: _NewSessionBody(projectId: projectId, projectName: projectName),
    );
  }
}

class _NewSessionBody extends StatefulWidget {
  final String projectId;
  final String? projectName;

  const _NewSessionBody({required this.projectId, required this.projectName});

  @override
  State<_NewSessionBody> createState() => _NewSessionBodyState();
}

class _NewSessionBodyState extends State<_NewSessionBody> {
  bool _dedicatedWorktree = true;
  bool _navigatingToCreatedSession = false;

  void _dismissScreen() {
    context.pop();
  }

  void _openAgentPicker(AgentModelData data) {
    final cubit = context.read<NewSessionCubit>();
    AgentPickerSheet.show(
      context,
      agents: data.agents,
      selectedAgent: data.agent ?? "",
      onAgentChanged: cubit.selectAgent,
    );
  }

  void _openModelPicker(AgentModelData data) {
    final cubit = context.read<NewSessionCubit>();
    final agentModel = data.agentModel;
    ModelPickerSheet.show(
      context,
      providers: data.providers,
      selectedProviderID: agentModel?.providerID ?? "",
      selectedModelID: agentModel?.modelID ?? "",
      onModelChanged: cubit.selectModel,
    );
  }

  void _openVariantPicker(AgentModelData data) {
    VariantPickerSheet.show(
      context,
      selectedVariantId: data.agentModel?.variant,
      availableVariants: data.availableVariants,
      onVariantChanged: context.read<NewSessionCubit>().selectVariant,
    );
  }

  Widget? _buildErrorBanner(NewSessionState state) {
    final zyra = context.zyra;
    final loc = context.loc;
    return switch (state) {
      NewSessionError(:final reason) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.localizedMessage(loc),
                style: TextStyle(color: zyra.colors.fgErrorPrimary),
              ),
            ),
          ],
        ),
      ),
      NewSessionIdle() => null,
      NewSessionSending() => null,
      NewSessionCreated() => null,
    };
  }

  Widget? _buildComposerHeader(NewSessionState state) {
    final data = state.agentModelData;
    final selectedAgent = data?.agent;
    if (data == null || data.agents.isEmpty || selectedAgent == null) return null;

    final modelName = _resolveModelName(data);
    return AgentModelButtons(
      availableVariants: data.availableVariants,
      modelName: modelName,
      selectedAgent: selectedAgent,
      selectedAgentModel: data.agentModel,
      onAgentTap: () => _openAgentPicker(data),
      onModelTap: () => _openModelPicker(data),
      onVariantTap: () => _openVariantPicker(data),
    );
  }

  String _resolveModelName(AgentModelData data) {
    final providerID = data.agentModel?.providerID;
    final modelID = data.agentModel?.modelID;
    final loc = context.loc;
    if (providerID == null || modelID == null) return loc.sessionDetailPickerModel;
    for (final provider in data.providers) {
      if (provider.id == providerID) {
        final model = provider.models[modelID];
        if (model != null) return model.name;
      }
    }
    if (modelID.isNotEmpty) return modelID;
    return loc.sessionDetailPickerModel;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewSessionCubit>().state;
    final loc = context.loc;
    final zyra = context.zyra;
    final isSending = state is NewSessionSending;
    // Captured at build time: the callbacks below can run while this route is
    // being torn down, where an ancestor lookup on a deactivated context
    // throws. Both references stay valid — the root messenger outlives this
    // route, and the route object is stable (`isCurrent` is still read at
    // event time).
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final modalRoute = ModalRoute.of(context);

    return BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (_, current) => current is NewSessionCreated,
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          // The user may have navigated elsewhere (e.g. opened another
          // session from the split-view list) while creation was in flight.
          // Replacing the route then would hijack their navigation — the
          // pop-time snackbar already told them the session continues.
          if (modalRoute != null && !modalRoute.isCurrent) return;
          _navigatingToCreatedSession = true;
          context.replaceRoute(
            AppRoute.sessionDetail(
              projectId: widget.projectId,
              projectName: widget.projectName,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        }
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && isSending && !_navigatingToCreatedSession) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(loc.newSessionLaunchingInBackground),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(title: Text(loc.sessionListNewSession)),
          body: Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(
                absorbing: isSending,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: Text(loc.newSessionDedicatedWorktree),
                              subtitle: Text(
                                loc.newSessionDedicatedWorktreeDescription,
                                style: zyra.textTheme.textXs.regular.copyWith(
                                  color: zyra.colors.textSecondary,
                                ),
                              ),
                              value: _dedicatedWorktree,
                              onChanged: (value) => setState(() => _dedicatedWorktree = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PromptInput(
                      isBusy: state is NewSessionSending,
                      onSend: (String text, String? command) {
                        context.read<NewSessionCubit>().createSession(
                          text: text,
                          command: command,
                          dedicatedWorktree: _dedicatedWorktree,
                        );
                      },
                      onAbort: _dismissScreen,
                      header: _buildErrorBanner(state),
                      composerHeader: _buildComposerHeader(state),
                      availableCommands: state.agentModelData?.commands ?? const [],
                      stagedCommand: state.agentModelData?.stagedCommand,
                      onCommandSelected: context.read<NewSessionCubit>().stageCommand,
                      onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
                    ),
                  ],
                ),
              ),
              if (isSending)
                NewSessionLoadingOverlay(
                  semanticsLabel: loc.newSessionLoadingSemantics,
                  messages: [
                    loc.newSessionLoadingMessage1,
                    loc.newSessionLoadingMessage2,
                    loc.newSessionLoadingMessage3,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
