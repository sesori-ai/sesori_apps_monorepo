import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../l10n/app_localizations.dart";
import "add_project_dialog.dart";

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProjectListCubit(
        getIt<ProjectService>(),
        getIt<ConnectionService>(),
        getIt<SseEventRepository>(),
        getIt<RouteSource>(),
      ),
      child: const _ProjectListBody(),
    );
  }
}

class _ProjectListBody extends StatefulWidget {
  const _ProjectListBody();

  @override
  State<_ProjectListBody> createState() => _ProjectListBodyState();
}

class _ProjectListBodyState extends State<_ProjectListBody> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _showProjectMenu(BuildContext context, Project project) {
    // Capture messenger and cubit before any Navigator.pop to avoid
    // post-pop context access.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final cubit = context.read<ProjectListCubit>();
    final loc = context.loc;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(loc.hideProject),
              onTap: () {
                Navigator.of(sheetContext).pop();
                cubit.hideProject(project.id);
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text(loc.projectHidden)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<ProjectListCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.projectListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: loc.notificationSettingsTitle,
            onPressed: () => context.pushRoute(AppRoute.notificationSettings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: loc.addProject,
        onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
        child: const Icon(Icons.add),
      ),
      body: switch (state) {
        ProjectListLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        ProjectListLoaded(:final projects, :final activityById) => RefreshIndicator(
          onRefresh: () async {
            final success = await context.read<ProjectListCubit>().refreshProjects();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(success ? loc.projectListRefreshSuccess : loc.projectListRefreshFailed)),
            );
          },
          child: projects.isEmpty
              ? CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_off_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(loc.noProjects, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              loc.addProjectPrompt,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
                              icon: const Icon(Icons.add),
                              label: Text(loc.addProject),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _ProjectTile(
                      project: project,
                      activeSessions: activityById[project.id] ?? 0,
                      onLongPress: () => _showProjectMenu(context, project),
                    );
                  },
                ),
        ),
        ProjectListFailed(:final error) => _ErrorView(
          error: error,
          onRetry: () => context.read<ProjectListCubit>().loadProjects(),
        ),
      },
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  final int activeSessions;
  final VoidCallback? onLongPress;

  const _ProjectTile({
    required this.project,
    required this.activeSessions,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final lastSegment = project.id.split("/").last;
    final displayName = project.name ?? (lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName);
    final updatedAt = project.time?.updated;
    final isActive = activeSessions > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.folder_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(displayName),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            project.id,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: .ellipsis,
          ),
          if (updatedAt != null)
            Text(
              loc.projectListUpdated(_formatTimestamp(updatedAt)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (isActive)
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  loc.projectListActiveSessions(activeSessions),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
      isThreeLine: updatedAt != null || isActive,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.read<ProjectListCubit>().setActiveProject(project);
        context.pushRoute(
          AppRoute.sessions,
          pathParams: {"projectId": project.id},
          queryParams: {"name": displayName},
        );
      },
      onLongPress: onLongPress,
    );
  }

  String _formatTimestamp(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 30) return "${diff.inDays}d ago";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}

class _ErrorView extends StatelessWidget {
  final ApiError error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              loc.projectListErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_describeError(loc, error), textAlign: .center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.projectListRetry),
            ),
          ],
        ),
      ),
    );
  }

  String _describeError(AppLocalizations loc, ApiError error) => switch (error) {
    NotAuthenticatedError() => loc.apiErrorNotAuthenticated,
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      rawErrorString != null
          ? loc.connectErrorNonSuccessCodeWithBody(
              errorCode,
              rawErrorString,
            )
          : loc.connectErrorNonSuccessCode(errorCode),
    DartHttpClientError(:final innerError) => loc.connectErrorConnectionFailed(innerError.toString()),
    JsonParsingError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}
