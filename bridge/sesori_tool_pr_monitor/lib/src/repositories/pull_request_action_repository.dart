import "../api/gh_cli_api.dart";

/// GitHub identity and, later, the monitor's writes on GitHub.
class PullRequestActionRepository({required final GhCliApi _api}) {
  String? _selfLogin;

  /// The login `gh` is signed in as, which tells the user's own comments
  /// from others'. Resolved once per bridge; a failed lookup throws its
  /// `GhCliException` and is retried on the next call.
  Future<String> selfLogin() async => _selfLogin ??= await _api.fetchAuthenticatedLogin();
}
