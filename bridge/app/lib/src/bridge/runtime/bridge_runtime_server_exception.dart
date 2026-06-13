/// Exception thrown when the bridge runtime cannot resolve the server
/// runtime during startup, including startup-mutex contention and singleton
/// replacement failures.
class BridgeRuntimeServerException implements Exception {
  const BridgeRuntimeServerException(this.message);

  final String message;

  @override
  String toString() => message;
}
