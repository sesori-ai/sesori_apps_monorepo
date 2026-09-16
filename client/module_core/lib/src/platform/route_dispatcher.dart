class RouteStack({required List<String> paths}) {
  final List<String> paths = List<String>.unmodifiable(paths);
}

abstract interface class RouteDispatcher() {
  /// Dismisses root popups, preserving pages and their Back stack.
  /// Implementations order this with [replaceStack] after navigator readiness.
  void dismissPopups();

  void replaceStack({required RouteStack stack});
}
