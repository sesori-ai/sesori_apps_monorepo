/// Core business logic for Sesori — pure Dart, no Flutter dependency.
library;

// Re-exports from sesori_auth (move + re-export pattern)
export "package:sesori_auth/sesori_auth.dart" show SecureStorage;
export "package:sesori_auth/sesori_auth.dart"
    show ApiError, DartHttpClientError, GenericError, JsonParsingError, NonSuccessCodeError, NotAuthenticatedError;
export "package:sesori_auth/sesori_auth.dart" show ApiResponse, ErrorResponse, SuccessResponse;
export "package:sesori_auth/sesori_auth.dart" show HttpMethod, SafeApiClient;
export "package:sesori_auth/sesori_auth.dart" show HttpApiClient;
// API
export "src/api/client/relay_http_client.dart";
export "src/capabilities/project/project_service.dart";
export "src/capabilities/relay/relay_client.dart";
export "src/capabilities/relay/relay_config.dart";
export "src/capabilities/relay/room_key_storage.dart";
export "src/capabilities/server_connection/connection_service.dart";
export "src/capabilities/server_connection/models/connection_status.dart";
export "src/capabilities/server_connection/models/sse_event.dart";
export "src/capabilities/server_connection/server_connection_config.dart";
export "src/capabilities/session/session_service.dart";
// Capabilities
export "src/capabilities/sse/session_activity_info.dart";
export "src/capabilities/sse/sse_event_repository.dart";
export "src/capabilities/voice/voice_api.dart";
// Cubits
export "src/cubits/connection_overlay/connection_overlay_cubit.dart";
export "src/cubits/login/login_cubit.dart";
export "src/cubits/login/login_state.dart";
export "src/cubits/project_list/project_list_cubit.dart";
export "src/cubits/project_list/project_list_state.dart";
export "src/cubits/session_detail/session_detail_cubit.dart";
export "src/cubits/session_detail/session_detail_state.dart";
export "src/cubits/session_list/session_list_cubit.dart";
export "src/cubits/session_list/session_list_state.dart";
// DI
export "src/di/injection.dart";
// Extensions
export "src/extensions/iterable_x.dart" hide IterableExtensions;
export "src/extensions/sugar_dart.dart";
// Logging
export "src/logging/logging.dart";
// Platform interfaces
export "src/platform/deep_link_source.dart";
export "src/platform/lifecycle_source.dart";
export "src/platform/url_launcher.dart";
// Reporting
export "src/reporting/reporting.dart";
// Routing
export "src/routing/app_routes.dart";
export "src/routing/auth_redirect_service.dart";
