final class VerifiedGithubLogin {
  final String login;

  const VerifiedGithubLogin._({required this.login});

  static VerifiedGithubLogin? tryParse({required String rawLogin}) {
    final login = rawLogin.trim().toLowerCase();
    if (login.isEmpty) {
      return null;
    }
    return VerifiedGithubLogin._(login: login);
  }
}
