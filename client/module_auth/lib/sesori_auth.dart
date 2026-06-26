/// Authentication package for Sesori — token lifecycle, OAuth flow, authenticated HTTP client.
library;

// $AuthUserCopyWith is the freezed-generated copyWith for AuthUser; re-export it
// alongside the type so downstream freezed models (e.g. SettingsState) with an
// AuthUser field can resolve their generated nested copyWith.
export "package:sesori_shared/sesori_shared.dart" show $AuthUserCopyWith, AuthProvider, AuthUser;

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
export "src/platform/oauth_device_descriptor_provider.dart";
export "src/platform/secure_storage.dart";
