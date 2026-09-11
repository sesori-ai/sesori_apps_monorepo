/// Answers whether management traffic targets this surface's supervised bridge.
abstract interface class ActiveBridgeLocality() {
  bool isLocalBridge({required String bridgeId});
}
