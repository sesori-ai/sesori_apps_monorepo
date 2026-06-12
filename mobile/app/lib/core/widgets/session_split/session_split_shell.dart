import "package:flutter/material.dart";

import "session_split_breakpoints.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
class SessionSplitShell extends StatelessWidget {
  final Widget list;
  final Widget child;

  const SessionSplitShell({
    super.key,
    required this.list,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= splitBreakpoint;

        if (!isWide) {
          return SessionSplitScope(
            isSplit: false,
            child: child,
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
                    child: list,
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
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
