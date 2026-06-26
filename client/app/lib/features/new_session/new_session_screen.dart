import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
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
        selectionTracker: getIt<NewSessionSelectionTracker>(),
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

  Widget? _buildErrorBanner(NewSessionState state) {
    final prego = context.prego;
    final loc = context.loc;
    return switch (state) {
      NewSessionError(:final reason) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.localizedMessage(loc),
                style: TextStyle(color: prego.colors.fgErrorPrimary),
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

    final cubit = context.read<NewSessionCubit>();
    return AgentModelButtons(
      agents: data.agents,
      selectedAgent: selectedAgent,
      onAgentSelected: cubit.selectAgent,
      providers: data.providers,
      selectedAgentModel: data.agentModel,
      onModelSelected: cubit.selectModel,
      availableVariants: data.availableVariants,
      onVariantSelected: cubit.selectVariant,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewSessionCubit>().state;
    final loc = context.loc;
    final prego = context.prego;
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
            // This pop can fire during the Navigator's build phase — e.g. when
            // opening another session from the split-view list while creation
            // is in flight, go_router swaps the underlying detail route in
            // place and pops this pushed new-session route in the same frame.
            // showSnackBar throws if called during build, so defer it to the
            // next frame. The captured root messenger outlives this route;
            // guard it with `mounted` since the route may already be gone.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!scaffoldMessenger.mounted) return;
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(loc.newSessionLaunchingInBackground),
                  duration: const Duration(seconds: 3),
                ),
              );
            });
          }
        },
        child: PregoGlassScaffold(
          title: loc.sessionListNewSession,
          // The loading scrim must dim the body while the glass back button
          // stays tappable (the user can abort while creation is in flight),
          // so it goes through the scaffold's bar-aware overlay slot rather
          // than an outer Stack that would also cover the bar.
          overlay: isSending
              ? NewSessionLoadingOverlay(
                  semanticsLabel: loc.newSessionLoadingSemantics,
                  messages: [
                    loc.newSessionLoadingMessage1,
                    loc.newSessionLoadingMessage2,
                    loc.newSessionLoadingMessage3,
                  ],
                )
              : null,
          slivers: [
            // The screen doesn't scroll: a single fill-remaining sliver holds
            // the worktree toggle at the top and pins the composer to the
            // bottom. With the scaffold's keyboard resize (Scaffold default),
            // the composer rides above the keyboard when the field is focused.
            SliverFillRemaining(
              hasScrollBody: false,
              child: AbsorbPointer(
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
                                style: prego.textTheme.textXs.regular.copyWith(
                                  color: prego.colors.textSecondary,
                                ),
                              ),
                              value: _dedicatedWorktree,
                              onChanged: (value) => setState(() => _dedicatedWorktree = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PromptInput(
                        // Persist the unsent prompt per project so it survives
                        // leaving and returning to the new-session screen before
                        // a session exists; cleared once the session is created.
                        draftKey: "new-session:${widget.projectId}",
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
