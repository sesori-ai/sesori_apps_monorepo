/// A failed `gh` call. [message] is actionable text an agent or a log can show
/// as is; variants that wrap a Dart error keep it in `innerError`.
sealed class const GhCliException() implements Exception {
  String get message;

  @override
  String toString() => message;
}

/// `gh` could not be started: it is not installed or not on the bridge's PATH.
final class const GhCliUnavailableException({required final Object innerError}) extends GhCliException {
  @override
  String get message =>
      "GitHub CLI (gh) is not installed or not on the bridge's PATH. "
      "Install it from https://cli.github.com, then run `gh auth login`.";
}

/// `gh` did not finish within [timeout] and was stopped.
final class const GhCliTimedOutException({
  required final Duration timeout,
  required final Object innerError,
}) extends GhCliException {
  @override
  String get message => "GitHub CLI (gh) did not answer within ${timeout.inSeconds} s.";
}

/// `gh` has no usable github.com credentials.
final class const GhCliUnauthenticatedException({required final String detail}) extends GhCliException {
  @override
  String get message =>
      "GitHub CLI (gh) is not signed in to github.com ($detail). "
      "Run `gh auth login`, or check `gh auth status`.";
}

/// GitHub says the repository or pull request does not exist, or the signed-in
/// account cannot see it.
final class const GhCliNotFoundException({required final String detail}) extends GhCliException {
  @override
  String get message => "GitHub could not find the pull request: $detail";
}

/// `gh` exited with an error that is none of the above, such as a network
/// failure or a GitHub server error. [httpStatus] is set when `gh` reported one.
final class const GhCliCommandFailedException({
  required final int exitCode,
  required final int? httpStatus,
  required final String detail,
}) extends GhCliException {
  @override
  String get message => "GitHub CLI (gh) failed: $detail";
}

/// GitHub answered with a GraphQL `errors` array. It is retryable even when
/// part of the data came back, because rate limits and transient service
/// failures arrive this way.
final class const GhCliGraphQlException({required final List<String> errors}) extends GhCliException {
  @override
  String get message => "GitHub returned an incomplete GraphQL response: ${errors.join("; ")}";
}

/// `gh` succeeded but its output was not the expected JSON.
final class const GhCliInvalidResponseException({required final Object innerError}) extends GhCliException {
  @override
  String get message => "GitHub CLI (gh) returned an unexpected response: $innerError";
}
