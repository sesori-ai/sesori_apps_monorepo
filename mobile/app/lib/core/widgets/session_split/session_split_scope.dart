import "package:flutter/material.dart";

/// Inherited widget that exposes adaptive split state to descendants.
///
/// Widgets in the session split shell can query whether they are rendering
/// inside a wide split layout and access the current project/session context.
class SessionSplitScope extends InheritedWidget {
  final bool isSplit;
  final String projectId;
  final String? selectedSessionId;

  const SessionSplitScope({
    super.key,
    required this.isSplit,
    required this.projectId,
    this.selectedSessionId,
    required super.child,
  });

  static SessionSplitScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw StateError("SessionSplitScope not found in BuildContext");
    }
    return scope;
  }

  static SessionSplitScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionSplitScope>();
  }

  @override
  bool updateShouldNotify(SessionSplitScope oldWidget) {
    return isSplit != oldWidget.isSplit ||
        projectId != oldWidget.projectId ||
        selectedSessionId != oldWidget.selectedSessionId;
  }
}
