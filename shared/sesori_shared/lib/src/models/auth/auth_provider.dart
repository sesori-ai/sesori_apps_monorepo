/// Enumeration of supported authentication providers.
///
/// Used across both bridge and mobile workspaces for consistent
/// provider identification in auth flows.
enum AuthProvider {
  /// GitHub OAuth provider
  github("github", "GitHub"),

  /// Google OAuth provider
  google("google", "Google"),

  /// Email/password provider
  email("email", "Email");

  const AuthProvider(this.key, this.label);

  /// URL path segment used in auth backend endpoints (e.g. `/auth/github`).
  final String key;

  /// Human-readable name for logging and error messages.
  final String label;

  /// Creates the correct variant by its [key], or `null` if unknown.
  static AuthProvider? fromKey(String? key) =>
      key == null
          ? null
          : AuthProvider.values.where((e) => e.key == key).firstOrNull;
}
