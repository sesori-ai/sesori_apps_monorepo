/// Hands the user to Sesori's page in the platform's app store.
abstract interface class AppReviewClient() {
  /// Opens the store page where the user can write a review. Failures are
  /// logged by the platform implementation; the user simply stays in Sesori.
  Future<void> openStoreReviewPage();
}
