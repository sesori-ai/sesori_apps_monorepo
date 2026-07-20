/// Core business logic for Sesori — pure Dart, no Flutter dependency.
library;

// Re-exports from sesori_auth (move + re-export pattern)
export "package:sesori_auth/sesori_auth.dart"
    show
        AuthAuthenticated,
        AuthAuthenticating,
        AuthFailed,
        AuthInitial,
        AuthSession,
        AuthState,
        AuthTokenProvider,
        AuthUnauthenticated,
        OAuthDeviceDescriptor,
        OAuthDeviceDescriptorProvider,
        OAuthFlowProvider,
        SecureStorage;
export "package:sesori_auth/sesori_auth.dart"
    show
        ApiError,
        DartHttpClientError,
        EmptyResponseError,
        GenericError,
        JsonParsingError,
        NonSuccessCodeError,
        NotAuthenticatedError;
export "package:sesori_auth/sesori_auth.dart" show ApiResponse, ErrorResponse, SuccessResponse;
export "package:sesori_auth/sesori_auth.dart" show HttpApiClient;
export "package:sesori_auth/sesori_auth.dart" show HttpMethod, SafeApiClient;
export "package:sesori_shared/sesori_shared.dart" show AuthProvider;

// API
export "src/api/client/relay_http_client.dart";
export "src/api/filesystem_api.dart";
export "src/api/notification_api.dart";
export "src/api/notification_preferences_api.dart";
export "src/api/plugin_api.dart";
export "src/api/plugin_preference_api.dart";
export "src/api/project_api.dart";
export "src/capabilities/notifications/register_token_request.dart";
export "src/capabilities/relay/relay_client.dart";
export "src/capabilities/relay/relay_config.dart";
export "src/capabilities/relay/room_key_storage.dart";
export "src/capabilities/server_connection/connection_service.dart";
export "src/capabilities/server_connection/models/connection_status.dart";
export "src/capabilities/server_connection/models/sse_event.dart";
export "src/capabilities/server_connection/server_connection_config.dart";
export "src/capabilities/session/session_service.dart";
// Capabilities
export "src/capabilities/voice/voice_api.dart";
// Cubits
export "src/cubits/connection_overlay/connection_overlay_cubit.dart";
export "src/cubits/connection_overlay/connection_overlay_state.dart";
export "src/cubits/login/login_cubit.dart";
export "src/cubits/login/login_failed_reason.dart";
export "src/cubits/login/login_state.dart";
export "src/cubits/new_session/new_session_cubit.dart";
export "src/cubits/new_session/new_session_state.dart";
export "src/cubits/notification_preferences/notification_preferences_cubit.dart";
export "src/cubits/notification_preferences/notification_preferences_state.dart";
export "src/cubits/plugin_management/plugin_management_cubit.dart";
export "src/cubits/plugin_management/plugin_management_state.dart";
export "src/cubits/project_list/add_project_outcome.dart";
export "src/cubits/project_list/project_list_cubit.dart";
export "src/cubits/project_list/project_list_state.dart";
export "src/cubits/session_detail/queued_session_submission.dart";
export "src/cubits/session_detail/session_detail_cubit.dart";
export "src/cubits/session_detail/session_detail_resolvers.dart";
export "src/cubits/session_detail/session_detail_state.dart";
export "src/cubits/session_diffs/diff_cubit.dart";
export "src/cubits/session_diffs/diff_state.dart";
export "src/cubits/session_list/session_list_cubit.dart";
export "src/cubits/session_list/session_list_state.dart";
export "src/cubits/settings/settings_cubit.dart";
export "src/cubits/settings/settings_state.dart";
export "src/cubits/splash/splash_cubit.dart";
export "src/cubits/splash/splash_state.dart";
// DI
export "src/di/injection.dart";
// Errors
export "src/errors/remote_failure_reason.dart";
// Logging
export "src/logging/logging.dart";
// Platform interfaces
export "src/platform/deep_link_source.dart";
export "src/platform/lifecycle_source.dart";
export "src/platform/local_notification_client.dart";
export "src/platform/notification_canceller.dart";
export "src/platform/notification_open_request.dart";
export "src/platform/push_messaging_source.dart";
export "src/platform/push_notification_message.dart";
export "src/platform/route_dispatcher.dart";
export "src/platform/route_source.dart";
export "src/platform/url_launcher.dart";
export "src/repositories/bridge_repository.dart";
export "src/repositories/models/plugin_management_result.dart";
export "src/repositories/models/repo_provider.dart";
export "src/repositories/notification_preferences_repository.dart";
export "src/repositories/notification_repository.dart";
export "src/repositories/permission_repository.dart";
export "src/repositories/plugin_preference_repository.dart";
export "src/repositories/plugin_repository.dart";
export "src/repositories/project_repository.dart";
export "src/repositories/registered_bridges_store.dart";
export "src/repositories/session_repository.dart";
// Routing
export "src/routing/app_routes.dart";
export "src/routing/notification_open_dispatcher.dart";
// Services
export "src/services/draft_store.dart";
export "src/services/foreground_notification_dispatcher.dart";
export "src/services/models/session_activity_info.dart";
export "src/services/new_session_plugin_service.dart";
export "src/services/new_session_selection_tracker.dart";
export "src/services/notification_registration_service.dart";
export "src/services/plugin_management_service.dart";
export "src/services/project_list_service.dart";
export "src/services/registered_bridges_service.dart";
export "src/services/session_detail_load_service.dart";
export "src/services/session_list_service.dart";
export "src/services/session_unseen_tracker.dart";
export "src/services/session_viewing_service.dart";
export "src/services/sse_event_tracker.dart";
// Utils
export "src/utils/command_filter/command_picker_entry_builder.dart";
export "src/utils/diff/diff_engine.dart";
export "src/utils/diff/language_detector.dart";
export "src/utils/model_filter/default_model_selector.dart";
export "src/utils/model_filter/model_picker_section_builder.dart";
