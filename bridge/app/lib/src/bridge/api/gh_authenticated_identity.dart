final class GhAuthenticatedIdentity {
  final String login;

  const GhAuthenticatedIdentity._({required this.login});

  static GhAuthenticatedIdentity? tryParse({required String rawLogin}) {
    final login = rawLogin.trim().toLowerCase();
    if (login.isEmpty) {
      return null;
    }
    return GhAuthenticatedIdentity._(login: login);
  }
}
