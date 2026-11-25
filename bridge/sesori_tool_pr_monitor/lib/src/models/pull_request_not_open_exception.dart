/// A label change was asked for a PR that is already merged or closed. The
/// label endpoints share the issue namespace, so they would accept it.
final class const PullRequestNotOpenException({required final bool merged}) implements Exception {
  String get message => "the PR is already ${merged ? "merged" : "closed"}.";

  @override
  String toString() => message;
}
