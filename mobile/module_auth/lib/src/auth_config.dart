const authBaseUrl = "https://api.sesori.com";

enum AuthProvider {
  github("github", "GitHub"),
  google("google", "Google"),
  email("email", "Email")
  ;

  const AuthProvider(this.key, this.label);

  /// URL path segment used in auth backend endpoints (e.g. `/auth/github`).
  final String key;

  /// Human-readable name for logging and error messages.
  final String label;

  static AuthProvider? fromKey(String? key) => switch (key) {
    "github" => AuthProvider.github,
    "google" => AuthProvider.google,
    "email" => AuthProvider.email,
    _ => null,
  };
}
