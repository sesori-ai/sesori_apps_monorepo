class RouteStack({required List<String> paths}) {
  final List<String> paths;

  this : paths = List<String>.unmodifiable(paths);
}

abstract interface class RouteDispatcher() {
  void replaceStack({required RouteStack stack});
}
