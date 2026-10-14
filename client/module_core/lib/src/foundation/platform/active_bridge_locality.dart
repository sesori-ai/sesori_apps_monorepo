/// Answers whether management traffic targets this surface's supervised bridge.
abstract interface class ActiveBridgeLocality() {
  bool isLocalBridge({required String bridgeId});

  /// The id of the bridge this surface supervises on its own computer, or
  /// `null` when it supervises none or its id is not known yet.
  String? get localBridgeId;

  /// [localBridgeId] as it changes.
  Stream<String?> get localBridgeIdStream;
}
