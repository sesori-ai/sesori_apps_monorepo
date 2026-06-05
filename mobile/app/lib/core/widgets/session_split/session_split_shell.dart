import "package:flutter/material.dart";

import "session_split_breakpoints.dart";
import "session_split_route_child.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
///
/// At widths below [splitBreakpoint] only the relevant content is shown:
/// the list for [SessionSplitRouteKind.list], or the detail child for
/// detail/diffs.
///
/// At or above [splitBreakpoint] a row with a fixed left list panel,
/// a divider, and a flexible right panel is rendered.
class SessionSplitShell extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String? selectedSessionId;
  final SessionSplitRouteKind routeKind;
  final Widget list;
  final Widget detail;

  const SessionSplitShell({
    super.key,
    required this.projectId,
    this.projectName,
    this.selectedSessionId,
    required this.routeKind,
    required this.list,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= splitBreakpoint;

        if (!isWide) {
          return SessionSplitScope(
            isSplit: false,
            projectId: projectId,
            selectedSessionId: selectedSessionId,
            child: switch (routeKind) {
              SessionSplitRouteKind.list => list,
              SessionSplitRouteKind.detail || SessionSplitRouteKind.diffs => detail,
            },
          );
        }

        final listWidth = (
          constraints.maxWidth * maxListPanelRatio
        ).clamp(minListPanelWidth, maxListPanelWidth);

        return Row(
          children: [
            SizedBox(
              key: const Key("session-split-left-pane"),
              width: listWidth,
              child: SessionSplitScope(
                isSplit: true,
                projectId: projectId,
                selectedSessionId: selectedSessionId,
                child: list,
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
                projectId: projectId,
                selectedSessionId: selectedSessionId,
                child: detail,
              ),
            ),
          ],
        );
      },
    );
  }
}
