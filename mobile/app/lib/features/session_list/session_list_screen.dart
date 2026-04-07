import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/constants.dart";
import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/status_colors.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";
import "../../l10n/app_localizations.dart";
import "pr_status_row.dart";
import "rename_session_dialog.dart";

part "session_list_actions.dart";
part "session_cleanup_dialogs.dart";
part "session_list_widgets.dart";

class SessionListScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;

  const SessionListScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        service: getIt<SessionService>(),
        projectService: getIt<ProjectService>(),
        connectionService: getIt<ConnectionService>(),
        sseEventRepository: getIt<SseEventRepository>(),
        projectId: projectId,
        failureReporter: getIt<FailureReporter>(),
      ),
      child: _SessionListBody(projectName: projectName),
    );
  }
}

class _SessionListBody extends StatelessWidget {
  final String? projectName;

  const _SessionListBody({this.projectName});

  void _goToNewSession({required BuildContext context}) {
    final projectId = context.read<SessionListCubit>().projectId;
    context.pushRoute(
      AppRoute.newSession(projectId: projectId),
    );
  }

  void _showSessionActions({required BuildContext context, required Session session}) {
    final loc = context.loc;
    final cubit = context.read<SessionListCubit>();
    final isArchived = session.time?.archived != null;

    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(loc.rename),
              onTap: () {
                sheetContext.pop();
                showRenameSessionDialog(
                  context: context,
                  session: session,
                  cubit: cubit,
                );
              },
            ),
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(isArchived ? loc.sessionListUnarchive : loc.sessionListArchive),
              onTap: () {
                sheetContext.pop();
                if (isArchived) {
                  _unarchiveSession(context: context, cubit: cubit, sessionId: session.id);
                } else {
                  _showArchiveSheet(context: context, cubit: cubit, session: session);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(
                loc.sessionListDelete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                sheetContext.pop();
                _showDeleteSheet(context: context, cubit: cubit, session: session);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final title = switch (projectName) {
      final name? => loc.sessionListTitleWithName(name),
      null => loc.sessionListTitle,
    };

    final showArchived = state is SessionListLoaded && state.showArchived;
    final baseBranch = state is SessionListLoaded ? state.baseBranch : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (baseBranch != null)
              Text(
                baseBranch,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: loc.sessionListToggleArchived,
            onPressed: state is SessionListLoaded ? () => context.read<SessionListCubit>().toggleArchived() : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToNewSession(context: context),
        tooltip: loc.sessionListNewSession,
        child: const Icon(Icons.add),
      ),
      body: switch (state) {
        SessionListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        SessionListLoaded(:final sessions, :final isRefreshing) => Column(
          children: [
            if (isRefreshing) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final success = await context.read<SessionListCubit>().refreshSessions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? loc.sessionListRefreshSuccess : loc.sessionListRefreshFailed),
                      duration: kSnackBarDuration,
                    ),
                  );
                },
                child: sessions.isEmpty
                    ? CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            child: Center(
                              child: Text(
                                showArchived ? loc.sessionListEmptyArchived : loc.sessionListEmpty,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final cubit = context.read<SessionListCubit>();
                          final isArchived = session.time?.archived != null;
                          final activityInfo = state.activeSessionIds[session.id];
                          return _SessionTile(
                            session: session,
                            isArchived: isArchived,
                            isActive: activityInfo != null,
                            awaitingInput: activityInfo?.awaitingInput ?? false,
                            backgroundTaskCount: activityInfo?.backgroundTaskCount ?? 0,
                            onLongPress: () => _showSessionActions(context: context, session: session),
                            onSwipe: () => isArchived
                                ? _unarchiveSession(context: context, cubit: cubit, sessionId: session.id)
                                : _showArchiveSheet(context: context, cubit: cubit, session: session),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        SessionListStaleProject() => _StaleProjectView(
          onBack: () => context.pop(),
        ),
        SessionListFailed(:final error) => _ErrorView(
          error: error,
          onRetry: () => context.read<SessionListCubit>().retryLoadSessions(),
        ),
      },
    );
  }
}
