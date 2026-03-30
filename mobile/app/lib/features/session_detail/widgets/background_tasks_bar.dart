import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../l10n/app_localizations.dart";

/// A floating bar shown above the prompt input when background tasks (child
/// sessions) exist. Collapsed it shows "N Tasks Running"; tapping expands to
/// reveal the individual task list with status + navigation.
///
/// Running tasks are always shown first. Completed tasks are hidden behind a
/// "Show N completed" toggle.
class BackgroundTasksBar extends StatefulWidget {
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const BackgroundTasksBar({
    super.key,
    required this.children,
    required this.childStatuses,
  });

  @override
  State<BackgroundTasksBar> createState() => _BackgroundTasksBarState();
}

class _BackgroundTasksBarState extends State<BackgroundTasksBar> {
  bool _expanded = false;
  bool _showCompleted = false;

  bool _isRunning(Session child) {
    final status = widget.childStatuses[child.id];
    return status is SessionStatusBusy || status is SessionStatusRetry;
  }

  int get _runningCount => widget.children.where(_isRunning).length;

  List<Session> get _runningTasks => widget.children.where(_isRunning).toList();

  List<Session> get _completedTasks => widget.children.where((c) => !_isRunning(c)).toList();

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final running = _runningTasks;
    final completed = _completedTasks;

    return Material(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CollapsedHeader(
            runningCount: _runningCount,
            totalCount: widget.children.length,
            expanded: _expanded,
            onTap: () => setState(() {
              _expanded = !_expanded;
              // Reset completed visibility when collapsing.
              if (!_expanded) _showCompleted = false;
            }),
          ),
          if (_expanded)
            _ExpandedTaskList(
              runningTasks: running,
              completedTasks: completed,
              childStatuses: widget.childStatuses,
              showCompleted: _showCompleted,
              onToggleCompleted: () => setState(() => _showCompleted = !_showCompleted),
            ),
        ],
      ),
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  final int runningCount;
  final int totalCount;
  final bool expanded;
  final VoidCallback onTap;

  const _CollapsedHeader({
    required this.runningCount,
    required this.totalCount,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final hasRunning = runningCount > 0;

    return InkWell(
      borderRadius: expanded ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (hasRunning)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasRunning ? loc.backgroundTasksRunning(runningCount) : loc.backgroundTasksCompleted,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedTaskList extends StatelessWidget {
  final List<Session> runningTasks;
  final List<Session> completedTasks;
  final Map<String, SessionStatus> childStatuses;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;

  const _ExpandedTaskList({
    required this.runningTasks,
    required this.completedTasks,
    required this.childStatuses,
    required this.showCompleted,
    required this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRunning = runningTasks.isNotEmpty;
    final hasCompleted = completedTasks.isNotEmpty;

    // When no running tasks, show completed directly (no toggle needed).
    final visibleTasks = hasRunning ? [...runningTasks, if (showCompleted) ...completedTasks] : completedTasks;

    // Show toggle only when there's a mix of running and completed.
    final showToggle = hasRunning && hasCompleted;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: visibleTasks.length + (showToggle ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 42,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          // Toggle button goes after visible tasks.
          if (index == visibleTasks.length) {
            return _CompletedToggle(
              completedCount: completedTasks.length,
              showCompleted: showCompleted,
              onTap: onToggleCompleted,
            );
          }

          final child = visibleTasks[index];
          return _TaskRow(
            session: child,
            status: childStatuses[child.id],
          );
        },
      ),
    );
  }
}

class _CompletedToggle extends StatelessWidget {
  final int completedCount;
  final bool showCompleted;
  final VoidCallback onTap;

  const _CompletedToggle({
    required this.completedCount,
    required this.showCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              showCompleted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                showCompleted ? loc.backgroundTasksHideCompleted : loc.backgroundTasksShowCompleted(completedCount),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final Session session;
  final SessionStatus? status;

  const _TaskRow({
    required this.session,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final title = session.title ?? loc.sessionDetailSubtaskUnnamed;

    return InkWell(
      onTap: () {
        context.pushRoute(
          AppRoute.sessionDetail(
            projectId: session.projectID,
            sessionId: session.id,
            readOnly: true,
            sessionTitle: session.title,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _statusIcon(status, theme),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _statusLabel(loc, status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(SessionStatus? status, ThemeData theme) => switch (status) {
    SessionStatusBusy() => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: theme.colorScheme.primary,
      ),
    ),
    SessionStatusRetry() => Icon(
      Icons.refresh,
      size: 16,
      color: theme.colorScheme.tertiary,
    ),
    SessionStatusIdle() => Icon(
      Icons.check_circle,
      size: 16,
      color: theme.colorScheme.primary,
    ),
    null => Icon(
      Icons.play_circle_outline,
      size: 16,
      color: theme.colorScheme.outline,
    ),
  };
  String _statusLabel(AppLocalizations loc, SessionStatus? status) => switch (status) {
    SessionStatusBusy() => loc.backgroundTaskStatusBusy,
    SessionStatusRetry() => loc.backgroundTaskStatusRetry,
    SessionStatusIdle() => _completedLabel(loc),
    null => _completedLabel(loc),
  };

  String _completedLabel(AppLocalizations loc) {
    final updatedMs = session.time?.updated;
    if (updatedMs == null) return loc.backgroundTaskStatusIdle;

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedMs),
    );

    if (diff.inMinutes < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 just now";
    if (diff.inHours < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inHours}h ago";
    return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inDays}d ago";
  }
}
