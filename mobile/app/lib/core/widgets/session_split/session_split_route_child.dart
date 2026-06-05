import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Identifies which kind of session route is currently active.
enum SessionSplitRouteKind {
  list,
  detail,
  diffs,
}

/// Typed wrapper around a GoRouter child widget that carries decoded route
/// metadata so the shell does not have to infer route kind from builder state.
class SessionSplitRouteChild extends StatelessWidget {
  final SessionSplitRouteKind routeKind;
  final AppRoute route;
  final Widget child;

  const SessionSplitRouteChild({
    super.key,
    required this.routeKind,
    required this.route,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
