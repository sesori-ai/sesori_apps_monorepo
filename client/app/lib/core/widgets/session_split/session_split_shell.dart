import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "session_split_breakpoints.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
class SessionSplitShell extends StatefulWidget {
  final Widget list;
  final Widget child;
  final ProjectViewingService projectViewingService;

  const SessionSplitShell({
    super.key,
    required this.list,
    required this.child,
    required this.projectViewingService,
  });

  @override
  State<SessionSplitShell> createState() => _SessionSplitShellState();
}

class _SessionSplitShellState extends State<SessionSplitShell> {
  late final ProjectViewingService _projectViewingService;
  late final ProjectViewPaneClaim _paneClaim;
  bool _listPaneVisible = false;

  @override
  void initState() {
    super.initState();
    _projectViewingService = widget.projectViewingService;
    _paneClaim = _projectViewingService.beginWideListPaneClaim();
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
        // with the root ScaffoldMessenger in split mode. Snackbars therefore
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
