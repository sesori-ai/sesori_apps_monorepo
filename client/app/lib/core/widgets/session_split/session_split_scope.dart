import "package:flutter/material.dart";

/// Inherited widget that exposes adaptive split state to descendants.
///
/// Widgets in the session split shell can query whether they are rendering
/// inside a wide split layout.
class const SessionSplitScope({
    super.key,
    required this.isSplit,
    required super.child,
  }) extends InheritedWidget {
  final bool isSplit;

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
    return isSplit != oldWidget.isSplit;
  }
}
