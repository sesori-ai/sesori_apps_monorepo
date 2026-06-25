import "package:injectable/injectable.dart";

import "../auth_manager.dart";
import "../interfaces/auth_session.dart";
import "../interfaces/auth_token_provider.dart";
import "../interfaces/oauth_flow_provider.dart";

/// Registers [AuthManager] under its three interface types so consumers can
/// inject whichever interface they need while sharing the same singleton.
@module
abstract class AuthModule {
  @lazySingleton
  AuthTokenProvider authTokenProvider(AuthManager m) => m;

  @lazySingleton
  OAuthFlowProvider oAuthFlowProvider(AuthManager m) => m;

  @lazySingleton
  AuthSession authSession(AuthManager m) => m;
}
