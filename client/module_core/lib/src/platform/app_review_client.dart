/// Asks the user for a review through the platform's app store. Failures are
/// logged by the platform implementation; the user simply stays in Sesori.
abstract interface class AppReviewClient() {
  /// Whether [requestReview] leaves Sesori for the store page instead of
  /// showing the OS review prompt in the app. It does on Android, where Play
  /// policy forbids the in-app prompt after Sesori's own question.
  bool get requestReviewOpensStore;

  /// Asks the OS for its review prompt, or opens the store page when
  /// [requestReviewOpensStore]. The OS may silently skip its prompt and never
  /// reports whether it appeared.
  Future<void> requestReview();

  /// Opens the store page where the user can write a review.
  Future<void> openStoreReviewPage();
}
