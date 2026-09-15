/// Resolves the bridge executable the desktop supervisor launches.
///
/// Development and installed-layout policy stays outside the pure-Dart
/// supervision service. Resolution validates the current installed bundle
/// before each spawn rather than caching a path across package replacement.
abstract interface class BridgeExecutablePathResolver() {
  String resolve();
}
