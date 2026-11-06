/// Asks the user for a review through the platform's app store. Failures are
/// logged by the platform implementation; the user simply stays in Sesori.
abstract interface class AppReviewClient() {
  /// Whether Sesori may ask its own "Are you enjoying Sesori?" question before
  /// [requestReview]. It may not on Android: Google Play's In-App Review
  /// policy forbids asking anything before its card, so there the automatic
  /// prompt requests the review directly.
  bool get allowsQuestionBeforeReview;

  /// Asks the OS for its in-app review prompt: StoreKit's on iOS, Play In-App
  /// Review's card on Android. The OS may silently skip it under its own quota
  /// and never reports whether it appeared.
  Future<void> requestReview();

  /// Opens the store page where the user can write a review.
  Future<void> openStoreReviewPage();
}
