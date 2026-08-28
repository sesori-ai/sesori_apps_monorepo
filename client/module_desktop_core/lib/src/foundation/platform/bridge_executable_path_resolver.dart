/// Resolves the bridge executable the desktop supervisor launches.
///
/// Development and product-shell path policy stays outside the pure-Dart
/// supervision service. Packaged-layout resolution will replace the desktop
/// shell's development default in the distribution plan.
abstract interface class BridgeExecutablePathResolver() {
  String resolve();
}
