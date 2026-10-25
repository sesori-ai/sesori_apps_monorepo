import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "session_split_breakpoints.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
///
/// It reports whether its list pane shows to the scope's [AllSessionsCubit],
/// which owns the wide-pane claim.
class const SessionSplitShell({
  super.key,
  required final Widget list,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<SessionSplitShell> createState() => _SessionSplitShellState();
}

class _SessionSplitShellState() extends State<SessionSplitShell> {
  late final AllSessionsCubit _sessions;
  bool _listPaneVisible = false;

  @override
  void initState() {
    super.initState();
    _sessions = context.read<AllSessionsCubit>();
  }

  void _reportListPanePresence({required bool isVisible}) {
    if (_listPaneVisible == isVisible) return;
    _listPaneVisible = isVisible;
    _sessions.setPaneVisible(isVisible: isVisible);
  }

  @override
  void dispose() {
    _reportListPanePresence(isVisible: false);
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
