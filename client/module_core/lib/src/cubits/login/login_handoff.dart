import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Whether the last attempt to open the sign-in page in the browser worked.
enum LoginBrowserLaunch() {
  opened,
  failed,
}

/// A browser sign-in waiting for the user: which provider, the auth-server
/// handoff to finish it, and whether the browser opened.
final class const LoginHandoff({
  required final OAuthProvider provider,
  required final OAuthHandoff oauth,
  required final LoginBrowserLaunch browser,
});
