/// Provides read access to the bridge id assigned by the auth server.
abstract interface class BridgeIdProvider {
  /// The current bridge id, or null when this bridge has not registered yet.
  String? get bridgeId;
}
