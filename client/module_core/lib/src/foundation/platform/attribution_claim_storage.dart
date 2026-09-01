/// App-container persistence for one-shot attribution claim markers, keyed by
/// `AttributionEvent.claimKey`.
abstract interface class AttributionClaimStorage() {
  Future<bool> isClaimed({required String claimKey});

  Future<void> markClaimed({required String claimKey});
}
