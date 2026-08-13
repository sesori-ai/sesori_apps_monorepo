import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "session_split_breakpoints.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
class const SessionSplitShell({
  super.key,
  required final Widget list,
  required final Widget child,
  required final ProjectViewingService projectViewingService,
}) extends StatefulWidget {
  @override
  State<SessionSplitShell> createState() => _SessionSplitShellState();
}

class _SessionSplitShellState() extends State<SessionSplitShell> {
  late ProjectViewingService _projectViewingService;
  late ProjectViewPaneClaim _paneClaim;
  bool _listPaneVisible = false;

  @override
  void initState() {
    super.initState();
    _projectViewingService = widget.projectViewingService;
    _paneClaim = _projectViewingService.beginWideListPaneClaim();
  }

  @override
  void didUpdateWidget(covariant SessionSplitShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.projectViewingService, widget.projectViewingService)) return;
    _projectViewingService.releaseWideListPaneClaim(claim: _paneClaim);
    _projectViewingService = widget.projectViewingService;
    _paneClaim = _projectViewingService.beginWideListPaneClaim();
    if (_listPaneVisible) {
      _projectViewingService.setWideListPaneVisible(
        claim: _paneClaim,
        isVisible: true,
      );
    }
  }

  void _reportListPanePresence({required bool isVisible}) {
    if (_listPaneVisible == isVisible) return;
    _listPaneVisible = isVisible;
    _projectViewingService.setWideListPaneVisible(
      claim: _paneClaim,
      isVisible: isVisible,
    );
  }

  @override
  void dispose() {
    _projectViewingService.releaseWideListPaneClaim(claim: _paneClaim);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= splitBreakpoint;
        _reportListPanePresence(isVisible: isWide);

        if (!isWide) {
          return SessionSplitScope(
            isSplit: false,
            child: widget.child,
          );
        }

        final listWidth = (constraints.maxWidth * maxListPanelRatio).clamp(minListPanelWidth, maxListPanelWidth);

        // The shell-level Scaffold is the single root Scaffold registered
        // with the root presentation overlay in split mode. Popup alerts therefore
        // present once, spanning both panes, instead of attaching to the
        // right pane's transient route Scaffolds (which also breaks when a
        // snackbar is shown mid pane-transition).
        return Scaffold(
          key: const Key("session-split-scaffold"),
          body: Row(
            children: [
              SizedBox(
                key: const Key("session-split-left-pane"),
                width: listWidth,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(
                    child: widget.list,
                  ),
                ),
              ),
              const VerticalDivider(
                key: Key("session-split-divider"),
                width: 1,
              ),
              Expanded(
                key: const Key("session-split-right-pane"),
                child: SessionSplitScope(
                  isSplit: true,
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
