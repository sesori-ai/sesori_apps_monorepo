/// Resolves the bridge executable the desktop supervisor launches.
///
/// Development and installed-layout policy stays outside the pure-Dart
/// supervision service. Resolution validates the current installed bundle
/// before each spawn rather than caching a path across package replacement.
abstract interface class BridgeExecutablePathResolver() {
  String resolve();
}

/// An executable refusal with repair guidance safe to render outside local logs.
abstract interface class BridgeExecutableResolutionException() implements Exception {
  String get userMessage;
}
