class RouteStack {
  final List<String> paths;

  RouteStack({required List<String> paths}) : paths = List<String>.unmodifiable(paths);
}

abstract interface class RouteDispatcher {
  void replaceStack({required RouteStack stack});
}
