import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
import "../../core/widgets/agent_picker_sheet.dart";
import "../../core/widgets/model_picker_sheet.dart";
import "../session_detail/widgets/prompt_input.dart";
import "widgets/branch_picker_sheet.dart";

class NewSessionScreen extends StatelessWidget {
  final String projectId;

  const NewSessionScreen({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSessionCubit(
        sessionService: getIt<SessionService>(),
        projectId: projectId,
      ),
      child: _NewSessionBody(projectId: projectId),
    );
  }
}

class _NewSessionBody extends StatefulWidget {
  final String projectId;

  const _NewSessionBody({required this.projectId});

  @override
  State<_NewSessionBody> createState() => _NewSessionBodyState();
}

class _NewSessionBodyState extends State<_NewSessionBody> {
  WorktreeMode _selectedWorktreeMode = WorktreeMode.none;
  String? _selectedBranch;

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
    ModelPickerSheet.show(
      context,
      providers: data.providers,
      selectedProviderID: data.providerID ?? "",
      selectedModelID: data.modelID ?? "",
      onModelChanged: cubit.selectModel,
    );
  }

  Future<void> _openBranchPicker() async {
    final result = await BranchPickerSheet.show(
      context,
      projectId: widget.projectId,
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedWorktreeMode = result.mode;
      _selectedBranch = result.branch;
    });
  }

  Widget _buildBranchSelector() {
    final theme = Theme.of(context);
    final loc = context.loc;

    final String title;
    final String? subtitle;

    if (_selectedBranch != null) {
      title = loc.branchPickerSelectedBranch(_selectedBranch!);
      subtitle = switch (_selectedWorktreeMode) {
        WorktreeMode.stayOnBranch => loc.branchPickerModeStay,
        WorktreeMode.newBranch => loc.branchPickerModeNew,
        WorktreeMode.none => null,
      };
    } else {
      title = loc.branchPickerUsingProjectDir;
      subtitle = null;
    }

    return ListTile(
      leading: Icon(
        _selectedBranch != null ? Icons.alt_route : Icons.folder_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: _openBranchPicker,
    );
  }

  Widget? _buildHeader(NewSessionState state) {
    final data = state.agentModelData;
    final selectedAgent = data?.agent;
    final agentButtons = data != null && data.agents.isNotEmpty && selectedAgent != null
        ? AgentModelButtons(
            providers: data.providers,
            selectedAgent: selectedAgent,
            selectedProviderID: data.providerID ?? "",
            selectedModelID: data.modelID ?? "",
            onAgentTap: () => _openAgentPicker(data),
            onModelTap: () => _openModelPicker(data),
          )
        : null;

    final errorBanner = switch (state) {
      NewSessionError(:final message) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
      NewSessionIdle() => null,
      NewSessionSending() => null,
      NewSessionCreated() => null,
    };

    if (agentButtons == null && errorBanner == null) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [agentButtons, errorBanner].whereType<Widget>().toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewSessionCubit>().state;
    final loc = context.loc;

    return BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (_, current) => current is NewSessionCreated,
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          _dismissScreen();
          context.pushRoute(
            AppRoute.sessionDetail(
              projectId: session.projectID,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(loc.sessionListNewSession)),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBranchSelector(),
                  ],
                ),
              ),
            ),
            PromptInput(
              isBusy: state is NewSessionSending,
              onSend: (text) {
                context.read<NewSessionCubit>().createSessionWithMessage(
                  text: text,
                  worktreeMode: _selectedWorktreeMode,
                  selectedBranch: _selectedBranch,
                );
              },
              onAbort: _dismissScreen,
              header: _buildHeader(state),
            ),
          ],
        ),
      ),
    );
  }
}
