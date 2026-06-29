import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "background_tasks_header.dart";
import "background_tasks_list.dart";

/// A floating glass card shown above the prompt input when background tasks
/// (child sessions) exist. Collapsed it shows "N Tasks Running"; tapping
/// expands the same glass surface to reveal the individual task list with
/// status + navigation.
///
/// The whole bar is a single liquid-glass surface (its own layer) so it reads
/// as one frosted card that grows, matching the glass pills in the composer
/// directly below it.
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

    final prego = context.prego;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(glassColor: prego.colors.buttonGlassPrimaryBackground),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? BackgroundTasksList(
                      projectId: widget.projectId,
                      runningTasks: _runningTasks,
                      completedTasks: _completedTasks,
                      childStatuses: widget.childStatuses,
                      showCompleted: _showCompleted,
                      onToggleCompleted: () => setState(() => _showCompleted = !_showCompleted),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
