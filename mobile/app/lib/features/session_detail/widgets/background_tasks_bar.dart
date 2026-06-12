import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";
import "background_tasks_header.dart";
import "background_tasks_list.dart";

/// A floating bar shown above the prompt input when background tasks (child
/// sessions) exist. Collapsed it shows "N Tasks Running"; tapping expands to
/// reveal the individual task list with status + navigation.
///
/// Running tasks are always shown first. Completed tasks are hidden behind a
/// "Show N completed" toggle.
class BackgroundTasksBar extends StatefulWidget {
  final String? projectId;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const BackgroundTasksBar({
    super.key,
    required this.projectId,
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

    final zyra = context.zyra;
    final running = _runningTasks;
    final completed = _completedTasks;

    return Material(
      elevation: 2,
      color: zyra.colors.bgTertiary,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BackgroundTasksHeader(
            runningCount: _runningCount,
            expanded: _expanded,
            onTap: () => setState(() {
              _expanded = !_expanded;
              // Reset completed visibility when collapsing.
              if (!_expanded) _showCompleted = false;
            }),
          ),
          if (_expanded)
            BackgroundTasksList(
              projectId: widget.projectId,
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
