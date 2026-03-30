import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../session_detail/widgets/prompt_input.dart";

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
      child: const _NewSessionBody(),
    );
  }
}

class _NewSessionBody extends StatefulWidget {
  const _NewSessionBody();

  @override
  State<_NewSessionBody> createState() => _NewSessionBodyState();
}

class _NewSessionBodyState extends State<_NewSessionBody> {
  bool _dedicatedWorktree = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewSessionCubit>().state;
    final loc = context.loc;

    return BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (_, current) => current is NewSessionCreated,
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          Navigator.of(context).pop();
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
                    SwitchListTile(
                      title: Text(loc.newSessionDedicatedWorktree),
                      subtitle: Text(
                        loc.newSessionDedicatedWorktreeDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              onSend: (text) {
                context.read<NewSessionCubit>().createSessionWithMessage(
                  text: text,
                  agent: null,
                  model: null,
                  dedicatedWorktree: _dedicatedWorktree,
                );
              },
              onAbort: () => Navigator.of(context).pop(),
              header: switch (state) {
                NewSessionError(:final message) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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
                _ => null,
              },
            ),
          ],
        ),
      ),
    );
  }
}
