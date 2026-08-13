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
export "src/api/analytics_api.dart";
export "src/api/bridge_settings_api.dart";
export "src/api/client/relay_http_client.dart";
export "src/api/filesystem_api.dart";
export "src/api/message_image_api.dart";
export "src/api/notification_api.dart";
export "src/api/notification_preferences_api.dart";
export "src/api/plugin_preference_api.dart";
export "src/api/product_analytics_preference_api.dart";
export "src/api/project_api.dart";
export "src/api/session_api.dart";
export "src/api/storage/composer_draft_storage.dart";
export "src/api/storage/notification_preferences_device_id_storage.dart";
export "src/api/storage/product_analytics_preference_storage.dart";
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
// Consumers
export "src/consumers/analytics/session_activity_analytics_listener.dart";
// Cubits
export "src/cubits/appearance/appearance_cubit.dart";
export "src/cubits/bridge_identity/bridge_identity_cubit.dart";
export "src/cubits/bridge_identity/bridge_identity_state.dart";
export "src/cubits/bridge_settings/bridge_settings_cubit.dart";
export "src/cubits/bridge_settings/bridge_settings_state.dart";
export "src/cubits/chat_input_mode/chat_input_mode_cubit.dart";
export "src/cubits/connection_overlay/connection_overlay_cubit.dart";
export "src/cubits/connection_overlay/connection_overlay_state.dart";
export "src/cubits/image_attachment_actions/image_attachment_actions_cubit.dart";
export "src/cubits/image_attachment_actions/image_attachment_actions_state.dart";
export "src/cubits/legal/legal_document_cubit.dart";
export "src/cubits/legal/legal_document_state.dart";
export "src/cubits/login/login_cubit.dart";
export "src/cubits/login/login_failed_reason.dart";
export "src/cubits/login/login_state.dart";
export "src/cubits/message_image/message_image_cubit.dart";
export "src/cubits/message_image/message_image_state.dart";
export "src/cubits/new_session/new_session_cubit.dart";
export "src/cubits/new_session/new_session_state.dart";
export "src/cubits/notification_preferences/notification_preferences_cubit.dart";
export "src/cubits/notification_preferences/notification_preferences_state.dart";
export "src/cubits/plugin_management/plugin_management_cubit.dart";
export "src/cubits/plugin_management/plugin_management_state.dart";
export "src/cubits/product_analytics_preference/product_analytics_preference_cubit.dart";
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
export "src/cubits/session_list/session_list_resolvers.dart";
export "src/cubits/session_list/session_list_state.dart";
export "src/cubits/settings/settings_cubit.dart";
export "src/cubits/settings/settings_state.dart";
export "src/cubits/splash/splash_cubit.dart";
export "src/cubits/splash/splash_state.dart";
// DI
export "src/di/injection.dart";
// Errors
export "src/errors/remote_failure_reason.dart";
// Analytics foundation
export "src/foundation/models/composer/composer_attachment.dart";
export "src/foundation/models/composer/composer_draft.dart";
export "src/foundation/models/product_analytics/analytics_runtime_capability.dart";
export "src/foundation/models/product_analytics/installation_analytics_event.dart";
export "src/foundation/models/product_analytics/product_analytics_event.dart";
export "src/foundation/models/product_analytics/product_analytics_preference.dart";
export "src/foundation/models/session_options/session_options_request_mode.dart";
export "src/foundation/platform/analytics_client.dart";
export "src/foundation/platform/attachment_thumbnail_storage.dart";
export "src/foundation/platform/image_clipboard.dart";
export "src/foundation/platform/image_saver.dart";
export "src/foundation/platform/image_sharer.dart";
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
export "src/repositories/analytics_repository.dart";
export "src/repositories/appearance_store.dart";
export "src/repositories/bridge_repository.dart";
export "src/repositories/bridge_settings_repository.dart";
export "src/repositories/chat_input_mode_store.dart";
export "src/repositories/composer_draft_repository.dart";
export "src/repositories/legal_repository.dart";
export "src/repositories/message_image_repository.dart";
export "src/repositories/models/analytics_delivery_result.dart";
export "src/repositories/models/bridge_settings_result.dart";
export "src/repositories/models/plugin_discovery_snapshot.dart";
export "src/repositories/models/plugin_management_result.dart";
export "src/repositories/models/product_analytics_preference_models.dart";
export "src/repositories/models/repo_provider.dart";
export "src/repositories/models/session_options_repository_result.dart";
export "src/repositories/notification_preferences_repository.dart";
export "src/repositories/notification_repository.dart";
export "src/repositories/permission_repository.dart";
export "src/repositories/plugin_preference_repository.dart";
export "src/repositories/plugin_repository.dart";
export "src/repositories/product_analytics_preference_repository.dart";
export "src/repositories/project_repository.dart";
export "src/repositories/registered_bridges_store.dart";
export "src/repositories/session_repository.dart";
// Routing
export "src/routing/analytics_route_listener.dart";
export "src/routing/app_routes.dart";
export "src/routing/notification_open_dispatcher.dart";
// Services
export "src/services/bridge_settings_service.dart";
export "src/services/composer_draft_calculator.dart";
export "src/services/foreground_notification_dispatcher.dart";
export "src/services/installation_analytics_service.dart";
export "src/services/message_thumbnail_cache_service.dart";
export "src/services/models/new_session_backend_scope.dart";
export "src/services/models/new_session_options_source.dart";
export "src/services/models/new_session_selection_intent.dart";
export "src/services/models/product_analytics_state.dart";
export "src/services/models/session_activity_info.dart";
export "src/services/models/session_list_item_state.dart";
export "src/services/new_session_options_service.dart";
export "src/services/new_session_plugin_service.dart";
export "src/services/new_session_selection_tracker.dart";
export "src/services/notification_preferences_service.dart";
export "src/services/notification_registration_service.dart";
export "src/services/plugin_management_service.dart";
export "src/services/product_analytics_service.dart";
export "src/services/project_list_service.dart";
export "src/services/project_viewing_service.dart";
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
