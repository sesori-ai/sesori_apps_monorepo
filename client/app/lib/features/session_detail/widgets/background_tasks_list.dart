import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_shared/sesori_shared.dart";
import "background_task_row.dart";
import "background_tasks_toggle.dart";

/// The expandable body of the background-tasks glass card: a glass divider
/// under the header, then the scrollable list of task rows. Running tasks come
/// first; completed tasks appear after a "Show N completed" toggle.
class BackgroundTasksList extends StatelessWidget {
  final String? projectId;
  final List<Session> runningTasks;
  final List<Session> completedTasks;
  final Map<String, SessionStatus> childStatuses;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;

  const BackgroundTasksList({
    super.key,
    required this.projectId,
    required this.runningTasks,
    required this.completedTasks,
    required this.childStatuses,
    required this.showCompleted,
    required this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final hasRunning = runningTasks.isNotEmpty;
    final hasCompleted = completedTasks.isNotEmpty;

    // When no running tasks, show completed directly (no toggle needed).
    final visibleTasks = hasRunning ? [...runningTasks, if (showCompleted) ...completedTasks] : completedTasks;

    // Show toggle only when there's a mix of running and completed.
    final showToggle = hasRunning && hasCompleted;
    final itemCount = visibleTasks.length + (showToggle ? 1 : 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassDivider(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // Toggle button goes after the visible tasks, as the last row.
              if (showToggle && index == visibleTasks.length) {
                return BackgroundTasksToggle(
                  completedCount: completedTasks.length,
                  showCompleted: showCompleted,
                  onTap: onToggleCompleted,
                );
              }

              final child = visibleTasks[index];
              // Suppress the final row's divider only when nothing follows it.
              final isLast = !showToggle && index == visibleTasks.length - 1;
              return BackgroundTaskRow(
                projectId: projectId,
                session: child,
                status: childStatuses[child.id],
                isLast: isLast,
              );
            },
          ),
        ),
      ],
    );
  }
}
