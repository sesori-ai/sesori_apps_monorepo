final class const VerifiedGithubLogin._({required this.login}) {
  final String login;

  static VerifiedGithubLogin? tryParse({required String rawLogin}) {
    final login = rawLogin.trim().toLowerCase();
    if (login.isEmpty) {
      return null;
    }
    return VerifiedGithubLogin._(login: login);
  }
}
