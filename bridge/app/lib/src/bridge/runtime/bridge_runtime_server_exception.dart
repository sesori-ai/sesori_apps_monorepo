/// Exception thrown when the bridge runtime cannot resolve the server
/// runtime during startup, including startup-mutex contention and singleton
/// replacement failures.
class const BridgeRuntimeServerException(this.message) implements Exception {
  final String message;

  @override
  String toString() => message;
}
