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
/// The collapsed header is the only thing that occupies layout space in the
/// bottom-controls cluster — the expanded card is painted in an [OverlayPortal]
/// anchored to that header, growing upward over the chat. Keeping the in-flow
/// footprint constant means opening/closing the card never changes the chat's
/// bottom inset, so the message list doesn't scroll when the card toggles.
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
  final OverlayPortalController _overlayController = OverlayPortalController();

  /// Links the floating expanded card to the in-flow collapsed header so it
  /// tracks the header's position (and grows upward from its bottom edge).
  final LayerLink _link = LayerLink();

  bool _expanded = false;
  bool _showCompleted = false;

  /// Width of the in-flow header, captured at layout so the floating card
  /// matches it exactly (the overlay otherwise gets the full-screen width).
  double _cardWidth = 0;

  bool _isRunning(Session child) {
    final status = widget.childStatuses[child.id];
    return status is SessionStatusBusy || status is SessionStatusRetry;
  }

  int get _runningCount => widget.children.where(_isRunning).length;

  List<Session> get _runningTasks => widget.children.where(_isRunning).toList();

  List<Session> get _completedTasks => widget.children.where((c) => !_isRunning(c)).toList();

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      // Reset completed visibility when collapsing.
      if (!_expanded) _showCompleted = false;
    });
    if (_expanded) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _cardWidth = constraints.maxWidth;
          return CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _overlayController,
              overlayChildBuilder: _buildOverlay,
              // In-flow footprint: only ever the collapsed header. While
              // expanded we maintain only its size (so the cluster height — and
              // thus the chat's bottom inset — stays constant) but NOT its
              // interactivity or semantics: it must drop out of hit-testing and
              // the focus/screen-reader order so the floating card above is the
              // single live surface. (Visibility.maintain would keep it
              // interactive and announced, hence plain Visibility here.)
              child: Visibility(
                visible: !_expanded,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: _buildCard(context, expanded: false),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        CompositedTransformFollower(
          link: _link,
          // Hide until linked so the card never flashes at the screen origin
          // before its header target is laid out (e.g. during route transitions).
          showWhenUnlinked: false,
          // Pin the card's bottom edge to the header's bottom edge so it grows
          // upward over the chat, leaving the composer below untouched.
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.bottomLeft,
          child: SizedBox(
            width: _cardWidth,
            child: _buildCard(context, expanded: true),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, {required bool expanded}) {
    final prego = context.prego;
    return GlassContainer(
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
            expanded: expanded,
            onTap: _toggleExpanded,
          ),
          if (expanded)
            BackgroundTasksList(
              projectId: widget.projectId,
              runningTasks: _runningTasks,
              completedTasks: _completedTasks,
              childStatuses: widget.childStatuses,
              showCompleted: _showCompleted,
              onToggleCompleted: () => setState(() => _showCompleted = !_showCompleted),
            ),
        ],
      ),
    );
  }
}
