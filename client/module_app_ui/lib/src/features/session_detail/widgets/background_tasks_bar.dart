import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "background_tasks_list.dart";

/// A small pill at the trailing edge of the composer's selector strip, shown
/// when the session has sub-agents (child sessions). While any of them works it
/// leads with a spinner and the running count; the total always follows behind
/// the sub-agent icon, so each number is read by the symbol next to it. It
/// never claims they are finished: an idle sub-agent can be resumed at any
/// time.
///
/// Tapping it opens the sub-agent list in an [OverlayPortal] beside the pill,
/// so the composer's footprint never changes and the list keeps tracking live
/// statuses while it is open.
class const BackgroundTasksBar({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final String? projectId,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,
}) extends StatefulWidget {
  @override
  State<BackgroundTasksBar> createState() => _BackgroundTasksBarState();
}

class _BackgroundTasksBarState() extends State<BackgroundTasksBar> {
  static const double _listWidth = 320;

  /// Between the pill and the list.
  static const double _gap = 6;

  /// Kept clear between the list and the edges of the screen.
  static const double _edgeMargin = 8;

  final OverlayPortalController _overlayController = OverlayPortalController();

  bool _isRunning(Session child) {
    final status = widget.childStatuses[child.id];
    return status is SessionStatusBusy || status is SessionStatusRetry;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final count = widget.children.length;
    final runningCount = widget.children.where(_isRunning).length;
    // The running count is what matters most, so the total steps back while
    // anything runs.
    final foreground = prego.colors.textSecondary;
    final totalForeground = runningCount > 0 ? prego.colors.textTertiary : foreground;
    final borderRadius = BorderRadius.circular(PregoRadius.full);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _overlayController,
      overlayChildBuilder: (context, info) => _buildOverlay(context: context, info: info),
      child: Tooltip(
        message: loc.subAgentsSummary(count, runningCount),
        child: Semantics(
          button: true,
          label: loc.subAgentsSummary(count, runningCount),
          onTap: _overlayController.toggle,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: pregoComposerSurfaceDecoration(
              prego: prego,
              style: widget.surfaceStyle,
              borderRadius: borderRadius,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey("sub_agents_pill"),
                onTap: _overlayController.toggle,
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        if (runningCount > 0) ...[
                          // A spinner fills its box; a 14px Tabler glyph draws
                          // about 12px, so this matches the icon beside it.
                          const SizedBox.square(dimension: 12, child: PregoActivityIndicator(color: null)),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 2),
                            child: Text(
                              "$runningCount",
                              style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textPrimary),
                            ),
                          ),
                        ],
                        Icon(TablerRegular.subtask, size: 14, color: totalForeground),
                        Text("$count", style: prego.textTheme.textXs.medium.copyWith(color: totalForeground)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay({required BuildContext context, required OverlayChildLayoutInfo info}) {
    final prego = context.prego;
    final running = widget.children.where(_isRunning).toList();
    final idle = widget.children.where((child) => !_isRunning(child)).toList();
    // A tall draft, an open keyboard or a short window can leave too little
    // room above the pill: the list then opens toward the roomier side and
    // scrolls within it instead of running off screen.
    final pill = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final screen = info.overlaySize;
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final roomAbove = pill.top - _gap - safe.top - _edgeMargin;
    final roomBelow = screen.height - keyboard - safe.bottom - _edgeMargin - pill.bottom - _gap;
    final opensUp = roomAbove >= roomBelow;

    return Stack(
      children: [
        // A tap anywhere else closes the list.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _overlayController.hide),
        ),
        Positioned(
          // The list's trailing edge lines up with the pill's.
          right: screen.width - pill.right,
          top: opensUp ? null : pill.bottom + _gap,
          bottom: opensUp ? screen.height - pill.top + _gap : null,
          width: math.min(_listWidth, pill.right - safe.left - _edgeMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(0, opensUp ? roomAbove : roomBelow)),
            child: PregoCard(
              surfaceStyle: widget.surfaceStyle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
                    child: Text(
                      context.loc.subAgentsTitle,
                      style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
                    ),
                  ),
                  Flexible(
                    child: BackgroundTasksList(
                      projectId: widget.projectId,
                      // Working sub-agents first; idle ones stay listed because
                      // they can be resumed.
                      tasks: [...running, ...idle],
                      childStatuses: widget.childStatuses,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
