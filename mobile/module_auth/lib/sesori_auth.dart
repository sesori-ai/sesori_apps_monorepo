/// Authentication package for Sesori — token lifecycle, OAuth flow, authenticated HTTP client.
library;

export "package:sesori_shared/sesori_shared.dart" show AuthProvider, AuthUser;

export "src/auth_config.dart";
export "src/client/api_error.dart";
export "src/client/api_response.dart";
export "src/client/authenticated_http_api_client.dart";
export "src/client/http_api_client.dart";
export "src/client/safe_api_client.dart";
export "src/di/injection.dart";
export "src/interfaces/auth_session.dart";
export "src/interfaces/auth_token_provider.dart";
export "src/interfaces/oauth_flow_provider.dart";
export "src/models/auth_state.dart";
export "src/platform/secure_storage.dart";
