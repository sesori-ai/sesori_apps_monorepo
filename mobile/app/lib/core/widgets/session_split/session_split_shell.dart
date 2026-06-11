import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../features/session_list/session_list_cubit_provider.dart";
import "../../../features/session_list/session_list_panel.dart";
import "../../../features/session_list/session_list_screen.dart";
import "../../routing/app_router.dart";
import "session_split_breakpoints.dart";
import "session_split_scope.dart";

/// Adaptive shell that renders either a single-pane narrow layout or a
/// two-pane wide layout for session routes.
class SessionSplitShell extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String? selectedSessionId;
  final Widget child;

  const SessionSplitShell({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.selectedSessionId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SessionListCubitProvider(
      key: ValueKey("session-list-cubit-$projectId"),
      projectId: projectId,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= splitBreakpoint;

          if (!isWide) {
            return SessionSplitScope(
              isSplit: false,
              child: child,
            );
          }

          final listWidth = (constraints.maxWidth * maxListPanelRatio).clamp(minListPanelWidth, maxListPanelWidth);

          return Row(
            children: [
              SizedBox(
                key: const Key("session-split-left-pane"),
                width: listWidth,
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(
                    child: _SessionListPane(
                      projectId: projectId,
                      projectName: projectName,
                      selectedSessionId: selectedSessionId,
                    ),
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
          );
        },
      ),
    );
  }
}

class _SessionListPane extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String? selectedSessionId;

  const _SessionListPane({
    required this.projectId,
    required this.projectName,
    required this.selectedSessionId,
  });

  @override
  Widget build(BuildContext context) {
    const actionDispatcher = SessionListActionDispatcher();
    // ignore: no_slop_linter/avoid_navigator_of, root navigator pop is required here so shell chrome exits the whole shell instead of the nested pane route
    final rootNavigator = Navigator.of(context);

    return KeyedSubtree(
      key: ValueKey("session-list-$projectId"),
      child: SessionListPanel(
        projectName: projectName,
        selectedSessionId: selectedSessionId,
        // Use the root navigator from shell chrome; GoRouter pop would target
        // the nested pane navigator and only pop the right-pane route.
        // ignore: unnecessary_lambdas, Navigator.pop is generic and does not match VoidCallback as a tear-off
        onBack: rootNavigator.canPop() ? () => rootNavigator.pop() : null,
        onNewSession: () => context.pushRoute(AppRoute.newSession(projectId: projectId)),
        onSessionTap: (session) {
          context.goRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        },
        onSessionLongPress: (session) => actionDispatcher.showSessionActions(context: context, session: session),
        onSessionSwipe: (session) => actionDispatcher.handleSessionSwipe(context: context, session: session),
      ),
    );
  }
}
