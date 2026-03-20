const authBaseUrl = "https://api.sesori.com";

enum OAuthProvider {
  github("github", "GitHub"),
  google("google", "Google")
  ;

  const OAuthProvider(this.key, this.label);

  /// URL path segment used in auth backend endpoints (e.g. `/auth/github`).
  final String key;

  /// Human-readable name for logging and error messages.
  final String label;

  static OAuthProvider? fromKey(String? key) => switch (key) {
    "github" => OAuthProvider.github,
    "google" => OAuthProvider.google,
    _ => null,
  };
}
