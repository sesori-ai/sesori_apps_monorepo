# Test Quality Review Round 2: Tracker

Review each test file one by one; mark status in the state file and regenerate.

- Total files: 641
- Reviewed: 641 (100%)

## `bridge/app` (238)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `api/app_onboarding_state_storage_test.dart` | - |
| 2 | keep | `api/control_secret_api_test.dart` | - |
| 3 | keep | `api/sesori_server_api_test.dart` | - |
| 4 | keep | `auth/bridge_id_migration_service_test.dart` | - |
| 5 | keep | `auth/bridge_id_storage_test.dart` | - |
| 6 | keep | `auth/bridge_registration_api_test.dart` | - |
| 7 | keep | `auth/bridge_registration_service_test.dart` | - |
| 8 | keep | `auth/jwt_expiry_test.dart` | - |
| 9 | keep | `auth/login_test.dart` | - |
| 10 | keep | `auth/profile_test.dart` | - |
| 11 | keep | `auth/token_manager_test.dart` | - |
| 12 | keep | `auth/token_test.dart` | - |
| 13 | keep | `auth/validate_test.dart` | - |
| 14 | keep | `bridge_config_service_test.dart` | - |
| 15 | keep | `bridge_settings_api_test.dart` | - |
| 16 | keep | `bridge_settings_repository_test.dart` | - |
| 17 | keep | `bridge_settings_test.dart` | - |
| 18 | keep | `bridge/api/gh_cli_api_test.dart` | - |
| 19 | keep | `bridge/api/git_cli_api_test.dart` | - |
| 20 | keep | `bridge/api/git_remote_api_test.dart` | - |
| 21 | keep | `bridge/client_test.dart` | - |
| 22 | keep | `bridge/debug_server_test.dart` | - |
| 23 | keep | `bridge/event_queue_test.dart` | - |
| 24 | keep | `bridge/foundation/filesystem_permission_validator_test.dart` | - |
| 25 | speedup | `bridge/foundation/process_runner_test.dart` | trailing 3s real wait for descendant exit in timeout test |
| 26 | keep | `bridge/key_exchange_test.dart` | - |
| 27 | keep | `bridge/log_failure_reporter_test.dart` | - |
| 28 | keep | `bridge/metadata_service_test.dart` | - |
| 29 | keep | `bridge/orchestrator_emit_bridge_event_test.dart` | - |
| 30 | keep | `bridge/orchestrator_error_recovery_test.dart` | - |
| 31 | keep | `bridge/orchestrator_registration_test.dart` | - |
| 32 | keep | `bridge/orchestrator_request_concurrency_test.dart` | - |
| 33 | keep | `bridge/orchestrator_token_reauth_test.dart` | - |
| 34 | keep | `bridge/persistence/catalog_queries_test.dart` | - |
| 35 | keep | `bridge/persistence/database_test.dart` | - |
| 36 | keep | `bridge/persistence/projects_dao_test.dart` | - |
| 37 | keep | `bridge/persistence/pull_request_dao_test.dart` | - |
| 38 | keep | `bridge/persistence/session_dao_test.dart` | - |
| 39 | keep | `bridge/persistence/session_options_cache_dao_test.dart` | - |
| 40 | keep | `bridge/plugin_to_shared_mapping_test.dart` | - |
| 41 | keep | `bridge/repositories/derived_session_builder_test.dart` | - |
| 42 | keep | `bridge/repositories/filesystem_repository_test.dart` | - |
| 43 | keep | `bridge/repositories/mappers/catalog_mappers_test.dart` | - |
| 44 | keep | `bridge/repositories/mappers/git_diff_output_mapper_test.dart` | - |
| 45 | keep | `bridge/repositories/mappers/git_remote_identity_parser_test.dart` | - |
| 46 | keep | `bridge/repositories/mappers/plugin_command_mapper_test.dart` | - |
| 47 | keep | `bridge/repositories/mappers/plugin_message_mapper_test.dart` | - |
| 48 | keep | `bridge/repositories/mappers/runtime_provision_progress_mapper_test.dart` | - |
| 49 | keep | `bridge/repositories/mappers/session_event_mapper_test.dart` | - |
| 50 | keep | `bridge/repositories/pr_source_repository_test.dart` | - |
| 51 | keep | `bridge/repositories/project_repository_test.dart` | - |
| 52 | keep | `bridge/repositories/pull_request_repository_test.dart` | - |
| 53 | keep | `bridge/repositories/question_repository_test.dart` | - |
| 54 | keep | `bridge/repositories/session_options_repository_test.dart` | - |
| 55 | keep | `bridge/repositories/session_repository_persistence_test.dart` | - |
| 56 | keep | `bridge/repositories/session_repository_test.dart` | - |
| 57 | keep | `bridge/repositories/session_unseen_calculator_test.dart` | - |
| 58 | keep | `bridge/repositories/trackers/session_event_tracker_test.dart` | - |
| 59 | keep | `bridge/repositories/worktree_repository_test.dart` | - |
| 60 | keep | `bridge/resume_test.dart` | - |
| 61 | cleaned | `bridge/routing/abort_session_handler_test.dart` | removed 2 duplicated tests (same assertion as 'extracts sessionId') |
| 62 | keep | `bridge/routing/bridge_restart_dispatcher_test.dart` | - |
| 63 | keep | `bridge/routing/catalog_read_handlers_test.dart` | - |
| 64 | keep | `bridge/routing/create_directory_handler_test.dart` | - |
| 65 | keep | `bridge/routing/create_project_handler_test.dart` | - |
| 66 | keep | `bridge/routing/create_session_handler_test.dart` | - |
| 67 | keep | `bridge/routing/delete_session_handler_test.dart` | - |
| 68 | keep | `bridge/routing/filesystem_suggestions_handler_test.dart` | - |
| 69 | keep | `bridge/routing/get_agents_handler_test.dart` | - |
| 70 | keep | `bridge/routing/get_base_branch_handler_test.dart` | - |
| 71 | keep | `bridge/routing/get_child_sessions_handler_test.dart` | - |
| 72 | keep | `bridge/routing/get_commands_handler_test.dart` | - |
| 73 | keep | `bridge/routing/get_current_project_handler_test.dart` | - |
| 74 | keep | `bridge/routing/get_plugin_management_handler_test.dart` | - |
| 75 | keep | `bridge/routing/get_plugin_setup_handler_test.dart` | - |
| 76 | keep | `bridge/routing/get_project_questions_handler_test.dart` | - |
| 77 | keep | `bridge/routing/get_projects_handler_test.dart` | - |
| 78 | keep | `bridge/routing/get_providers_handler_test.dart` | - |
| 79 | keep | `bridge/routing/get_session_diffs_handler_success_test.dart` | - |
| 80 | keep | `bridge/routing/get_session_diffs_handler_test.dart` | - |
| 81 | keep | `bridge/routing/get_session_messages_handler_test.dart` | - |
| 82 | keep | `bridge/routing/get_session_permissions_handler_test.dart` | - |
| 83 | keep | `bridge/routing/get_session_questions_handler_test.dart` | - |
| 84 | keep | `bridge/routing/get_session_statuses_handler_test.dart` | - |
| 85 | keep | `bridge/routing/get_sessions_handler_test.dart` | - |
| 86 | keep | `bridge/routing/health_check_handler_test.dart` | - |
| 87 | keep | `bridge/routing/hide_project_handler_test.dart` | - |
| 88 | keep | `bridge/routing/open_project_handler_test.dart` | - |
| 89 | keep | `bridge/routing/patch_plugin_idle_timeout_handler_test.dart` | - |
| 90 | keep | `bridge/routing/post_agents_handler_test.dart` | - |
| 91 | keep | `bridge/routing/post_plugin_lifecycle_command_handler_test.dart` | - |
| 92 | keep | `bridge/routing/post_session_options_handler_test.dart` | - |
| 93 | keep | `bridge/routing/reject_question_handler_test.dart` | - |
| 94 | keep | `bridge/routing/rename_project_handler_test.dart` | - |
| 95 | keep | `bridge/routing/rename_session_handler_test.dart` | - |
| 96 | keep | `bridge/routing/reply_to_permission_handler_test.dart` | - |
| 97 | keep | `bridge/routing/reply_to_question_handler_test.dart` | - |
| 98 | keep | `bridge/routing/request_handler_test.dart` | - |
| 99 | keep | `bridge/routing/request_router_test.dart` | - |
| 100 | keep | `bridge/routing/restart_bridge_handler_test.dart` | - |
| 101 | keep | `bridge/routing/routed_request_dispatcher_test.dart` | - |
| 102 | keep | `bridge/routing/send_prompt_handler_test.dart` | - |
| 103 | keep | `bridge/routing/set_base_branch_handler_test.dart` | - |
| 104 | keep | `bridge/routing/update_session_archive_status_handler_test.dart` | - |
| 105 | keep | `bridge/runtime/bridge_cli_dispatch_test.dart` | - |
| 106 | keep | `bridge/runtime/bridge_cli_options_test.dart` | - |
| 107 | keep | `bridge/runtime/bridge_logout_runner_test.dart` | - |
| 108 | keep | `bridge/runtime/bridge_runtime_auth_test.dart` | - |
| 109 | keep | `bridge/runtime/bridge_runtime_builder_test.dart` | - |
| 110 | keep | `bridge/runtime/bridge_runtime_runner_test.dart` | - |
| 111 | keep | `bridge/runtime/bridge_shutdown_coordinator_test.dart` | - |
| 112 | keep | `bridge/runtime/catalog_import_startup_test.dart` | - |
| 113 | keep | `bridge/runtime/plugin_cli_options_mapper_test.dart` | - |
| 114 | keep | `bridge/runtime/plugin_generation_factory_test.dart` | - |
| 115 | keep | `bridge/runtime/plugin_registry_test.dart` | - |
| 116 | keep | `bridge/runtime/plugin_runtime_test.dart` | - |
| 117 | keep | `bridge/runtime/run_command_catalog_import_test.dart` | - |
| 118 | keep | `bridge/runtime/runtime_provision_formatter_test.dart` | - |
| 119 | keep | `bridge/services/deleted_session_storage_cleanup_service_test.dart` | - |
| 120 | keep | `bridge/services/pending_interaction_service_test.dart` | - |
| 121 | keep | `bridge/services/pr_sync_service_test.dart` | - |
| 122 | keep | `bridge/services/project_activity_service_test.dart` | - |
| 123 | keep | `bridge/services/project_mutation_service_test.dart` | - |
| 124 | keep | `bridge/services/session_abort_service_test.dart` | - |
| 125 | keep | `bridge/services/session_creation_service_test.dart` | - |
| 126 | keep | `bridge/services/session_diff_service_integration_test.dart` | - |
| 127 | keep | `bridge/services/session_event_dispatcher_test.dart` | - |
| 128 | keep | `bridge/services/session_event_service_test.dart` | - |
| 129 | keep | `bridge/services/session_family_mutation_test.dart` | - |
| 130 | keep | `bridge/services/session_lifecycle_service_test.dart` | - |
| 131 | keep | `bridge/services/session_mutation_dispatcher_test.dart` | - |
| 132 | keep | `bridge/services/session_operation_dispatcher_test.dart` | - |
| 133 | keep | `bridge/services/session_options_service_test.dart` | - |
| 134 | keep | `bridge/services/session_prompt_service_test.dart` | - |
| 135 | keep | `bridge/services/session_unseen_service_test.dart` | - |
| 136 | keep | `bridge/services/session_view_tracker_test.dart` | - |
| 137 | keep | `bridge/sse_manager_test.dart` | - |
| 138 | keep | `bridge/sse/bridge_event_mapper_test.dart` | - |
| 139 | keep | `bridge/worktree_service_git_test.dart` | - |
| 140 | keep | `bridge/worktree_service_test.dart` | - |
| 141 | keep | `control/bridge_control_message_dispatcher_test.dart` | - |
| 142 | keep | `control/control_channel_loss_listener_test.dart` | - |
| 143 | keep | `control/control_provision_notifier_test.dart` | - |
| 144 | keep | `control/control_status_notifier_test.dart` | - |
| 145 | keep | `default_editor_repository_test.dart` | - |
| 146 | keep | `device_type_detector_test.dart` | - |
| 147 | keep | `drift/default/migration_test.dart` | - |
| 148 | keep | `foundation/app_connection_wait_indicator_test.dart` | - |
| 149 | keep | `foundation/app_onboarding_formatter_test.dart` | - |
| 150 | keep | `foundation/control_channel_client_test.dart` | - |
| 151 | keep | `integration/pr_sync_fk_regression_test.dart` | - |
| 152 | keep | `linux_wake_lock_api_test.dart` | - |
| 153 | keep | `listeners/catalog_import_console_listener_test.dart` | - |
| 154 | keep | `listeners/plugin_event_listener_test.dart` | - |
| 155 | keep | `listeners/session_event_trigger_listeners_test.dart` | - |
| 156 | keep | `listeners/session_options_refresh_listeners_test.dart` | - |
| 157 | keep | `listeners/viewed_project_pr_refresh_listener_test.dart` | - |
| 158 | keep | `macos_wake_lock_api_test.dart` | - |
| 159 | keep | `persistence/database_path_test.dart` | - |
| 160 | keep | `persistence/session_dao_test.dart` | - |
| 161 | keep | `platform_default_editor_api_test.dart` | - |
| 162 | keep | `push/completion_notifier_test.dart` | - |
| 163 | keep | `push/completion_push_listener_test.dart` | - |
| 164 | keep | `push/maintenance_push_listener_test.dart` | - |
| 165 | keep | `push/push_dispatcher_test.dart` | - |
| 166 | keep | `push/push_maintenance_telemetry_test.dart` | - |
| 167 | keep | `push/push_notification_client_test.dart` | - |
| 168 | keep | `push/push_notification_content_builder_test.dart` | - |
| 169 | keep | `push/push_rate_limiter_test.dart` | - |
| 170 | keep | `push/push_session_state_tracker_test.dart` | - |
| 171 | keep | `repositories/app_client_status_repository_test.dart` | - |
| 172 | keep | `repositories/app_onboarding_state_repository_test.dart` | - |
| 173 | keep | `repositories/catalog_import_repository_test.dart` | - |
| 174 | keep | `repositories/project_catalog_identity_calculator_test.dart` | - |
| 175 | keep | `routing/catalog_import_handlers_test.dart` | - |
| 176 | keep | `routing/pull_request_refresh_settings_handlers_test.dart` | - |
| 177 | keep | `server/api/process_id_lookup_api_test.dart` | - |
| 178 | keep | `server/api/system_process_api_test.dart` | - |
| 179 | keep | `server/api/terminal_prompt_api_test.dart` | - |
| 180 | keep | `server/foundation/bridge_restart_command_builder_test.dart` | - |
| 181 | keep | `server/host/bridge_host_info_impl_test.dart` | - |
| 182 | keep | `server/host/bridge_host_json_store_test.dart` | - |
| 183 | keep | `server/host/bridge_host_port_service_test.dart` | - |
| 184 | keep | `server/host/bridge_host_process_service_test.dart` | - |
| 185 | keep | `server/host/bridge_plugin_host_impl_test.dart` | - |
| 186 | keep | `server/host/plugin_state_directory_test.dart` | - |
| 187 | keep | `server/loopback_port_api_test.dart` | - |
| 188 | keep | `server/models/bridge_startup_lock_test.dart` | - |
| 189 | keep | `server/port_repository_test.dart` | - |
| 190 | keep | `server/repositories/bridge_instance_repository_test.dart` | - |
| 191 | keep | `server/repositories/process_repository_test.dart` | - |
| 192 | keep | `server/repositories/terminal_prompt_repository_test.dart` | - |
| 193 | keep | `server/runtime_file_api_test.dart` | - |
| 194 | keep | `server/services/bridge_instance_service_test.dart` | - |
| 195 | keep | `server/services/bridge_restart_service_test.dart` | - |
| 196 | keep | `server/startup_mutex_repository_test.dart` | - |
| 197 | keep | `services/app_client_onboarding_service_test.dart` | - |
| 198 | keep | `services/catalog_import_service_test.dart` | - |
| 199 | keep | `services/control_channel_token_service_test.dart` | - |
| 200 | keep | `services/control_prompt_service_test.dart` | - |
| 201 | keep | `services/control_unregister_service_test.dart` | - |
| 202 | keep | `services/plugin_lifecycle_service_test.dart` | - |
| 203 | keep | `services/project_view_tracker_test.dart` | - |
| 204 | keep | `services/pull_request_refresh_settings_service_test.dart` | - |
| 205 | keep | `sleep_prevention_service_test.dart` | - |
| 206 | keep | `tool/bump_version_test.dart` | - |
| 207 | keep | `tool/installers_test.dart` | - |
| 208 | keep | `tool/npm_wrapper_test.dart` | - |
| 209 | keep | `tool/sync_versions_test.dart` | - |
| 210 | keep | `updater/checksum_manifest_api_test.dart` | - |
| 211 | keep | `updater/github_releases_api_test.dart` | - |
| 212 | keep | `updater/managed_runtime_manifest_api_test.dart` | - |
| 213 | keep | `updater/manual_update_service_test.dart` | - |
| 214 | keep | `updater/platform_info_test.dart` | - |
| 215 | keep | `updater/posix_update_api_test.dart` | - |
| 216 | keep | `updater/release_contract_test.dart` | - |
| 217 | keep | `updater/release_repository_test.dart` | - |
| 218 | keep | `updater/release_track_test.dart` | - |
| 219 | keep | `updater/terminal_download_progress_listener_test.dart` | - |
| 220 | keep | `updater/update_apply_service_test.dart` | - |
| 221 | keep | `updater/update_artifact_repository_test.dart` | - |
| 222 | keep | `updater/update_attempt_api_test.dart` | - |
| 223 | keep | `updater/update_attempt_repository_test.dart` | - |
| 224 | keep | `updater/update_cache_test.dart` | - |
| 225 | keep | `updater/update_command_formatter_test.dart` | - |
| 226 | keep | `updater/update_install_service_test.dart` | - |
| 227 | keep | `updater/update_lifecycle_service_test.dart` | - |
| 228 | keep | `updater/update_lock_test.dart` | - |
| 229 | keep | `updater/update_log_api_test.dart` | - |
| 230 | keep | `updater/update_message_formatter_test.dart` | - |
| 231 | keep | `updater/update_output_formatter_test.dart` | - |
| 232 | keep | `updater/update_policy_test.dart` | - |
| 233 | keep | `updater/update_reconciliation_service_test.dart` | - |
| 234 | keep | `updater/update_service_test.dart` | - |
| 235 | keep | `updater/windows_update_api_test.dart` | - |
| 236 | keep | `version_test.dart` | - |
| 237 | keep | `wake_lock_repository_test.dart` | - |
| 238 | keep | `windows_wake_lock_api_test.dart` | - |

## `bridge/sesori_bridge_foundation` (9)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `archive_extractor_test.dart` | no changes |
| 2 | keep | `binary_download_client_test.dart` | no changes |
| 3 | keep | `checksum_validator_test.dart` | no changes |
| 4 | keep | `host_process_command_executor_test.dart` | no changes |
| 5 | keep | `os_version_formatter_test.dart` | no changes |
| 6 | keep | `platform_target_test.dart` | no changes |
| 7 | keep | `project_directory_test.dart` | no changes |
| 8 | keep | `semantic_version_test.dart` | no changes |
| 9 | keep | `sesori_data_directory_test.dart` | no changes |

## `bridge/sesori_plugin_acp` (19)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `acp_approval_registry_test.dart` | no changes |
| 2 | keep | `acp_commands_test.dart` | no changes |
| 3 | keep | `acp_content_mapper_test.dart` | no changes |
| 4 | keep | `acp_event_mapper_test.dart` | no changes |
| 5 | keep | `acp_history_replay_test.dart` | no changes |
| 6 | keep | `acp_initialize_test.dart` | no changes |
| 7 | keep | `acp_plugin_activity_test.dart` | no changes |
| 8 | keep | `acp_plugin_projects_test.dart` | no changes |
| 9 | keep | `acp_protocol_test.dart` | no changes |
| 10 | keep | `acp_reconnect_test.dart` | no changes |
| 11 | keep | `acp_resume_only_test.dart` | no changes |
| 12 | keep | `acp_resume_test.dart` | no changes |
| 13 | keep | `acp_session_loader_test.dart` | no changes |
| 14 | keep | `acp_session_options_service_test.dart` | no changes |
| 15 | keep | `acp_stdio_client_test.dart` | no changes |
| 16 | keep | `acp_tool_content_integration_test.dart` | no changes |
| 17 | keep | `acp_turn_serialization_test.dart` | no changes |
| 18 | keep | `repositories/trackers/acp_content_tracker_test.dart` | no changes |
| 19 | keep | `repositories/trackers/acp_tool_content_tracker_test.dart` | no changes |

## `bridge/sesori_plugin_codex` (23)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `approval_registry_test.dart` | no changes |
| 2 | keep | `codex_catalog_repository_test.dart` | no changes |
| 3 | keep | `codex_command_execution_parser_test.dart` | no changes |
| 4 | keep | `codex_config_reader_test.dart` | no changes |
| 5 | keep | `codex_event_mapper_test.dart` | no changes |
| 6 | keep | `codex_image_attachment_mapper_test.dart` | no changes |
| 7 | keep | `codex_image_bearing_item_parser_test.dart` | no changes |
| 8 | keep | `codex_metadata_repository_test.dart` | no changes |
| 9 | keep | `codex_model_repository_test.dart` | no changes |
| 10 | keep | `codex_plugin_impl_test.dart` | no changes |
| 11 | keep | `codex_plugin_phase6_test.dart` | no changes |
| 12 | keep | `codex_plugin_write_path_test.dart` | no changes |
| 13 | keep | `codex_rollout_api_test.dart` | no changes |
| 14 | keep | `codex_rollout_tailer_test.dart` | no changes |
| 15 | keep | `codex_session_service_test.dart` | no changes |
| 16 | keep | `codex_skill_repository_test.dart` | no changes |
| 17 | keep | `codex_tool_lifecycle_tracker_test.dart` | no changes |
| 18 | keep | `codex_tool_outcome_repository_test.dart` | no changes |
| 19 | keep | `runtime/codex_ownership_record_test.dart` | no changes |
| 20 | keep | `runtime/codex_plugin_descriptor_setup_test.dart` | no changes |
| 21 | keep | `runtime/codex_runtime_manifest_test.dart` | no changes |
| 22 | keep | `runtime/codex_runtime_policy_test.dart` | no changes |
| 23 | keep | `runtime/codex_status_reporter_test.dart` | no changes |

## `bridge/sesori_plugin_cursor` (9)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `cursor_approval_registry_test.dart` | no changes |
| 2 | keep | `cursor_catalog_repository_test.dart` | no changes |
| 3 | keep | `cursor_catalog_service_test.dart` | no changes |
| 4 | keep | `cursor_catalog_tracker_test.dart` | no changes |
| 5 | keep | `cursor_event_mapper_test.dart` | no changes |
| 6 | keep | `cursor_plugin_descriptor_availability_test.dart` | no changes |
| 7 | keep | `cursor_plugin_test.dart` | no changes |
| 8 | keep | `cursor_session_cleanup_service_test.dart` | no changes |
| 9 | keep | `cursor_session_options_service_test.dart` | no changes |

## `bridge/sesori_plugin_interface` (20)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `ansi_color_test.dart` | no changes |
| 2 | keep | `buffered_stream_test.dart` | no changes |
| 3 | keep | `console_test.dart` | no changes |
| 4 | keep | `lifecycle/bridge_plugin_descriptor_test.dart` | no changes |
| 5 | keep | `lifecycle/plugin_config_test.dart` | no changes |
| 6 | keep | `lifecycle/plugin_diagnostics_test.dart` | no changes |
| 7 | keep | `lifecycle/plugin_status_controller_test.dart` | no changes |
| 8 | keep | `lifecycle/plugin_status_test.dart` | no changes |
| 9 | keep | `lifecycle/plugin_work_state_test.dart` | no changes |
| 10 | keep | `lifecycle/start_abort_signal_test.dart` | no changes |
| 11 | keep | `lifecycle/steady_plugin_lifecycle_test.dart` | no changes |
| 12 | keep | `log_test.dart` | no changes |
| 13 | keep | `plugin_operation_exception_test.dart` | no changes |
| 14 | keep | `plugin_project_test.dart` | no changes |
| 15 | cleaned | `plugin_session_options_test.dart` | deleted 2 vacuous constructor tests |
| 16 | keep | `process/process_identity_test.dart` | no changes |
| 17 | keep | `process/process_user_test.dart` | no changes |
| 18 | deleted | `process/signal_result_test.dart` | data class, vacuous |
| 19 | keep | `terminal_color_validator_test.dart` | no changes |
| 20 | keep | `terminal_glyph_validator_test.dart` | no changes |

## `bridge/sesori_plugin_opencode` (20)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `active_session_tracker_test.dart` | no changes |
| 2 | keep | `assistant_message_mapper_test.dart` | no changes |
| 3 | keep | `message_part_mapper_test.dart` | no changes |
| 4 | keep | `open_code_raw_http_client_test.dart` | no changes |
| 5 | keep | `openapi_models_round_trip_test.dart` | no changes |
| 6 | keep | `opencode_api_http_test.dart` | no changes |
| 7 | keep | `opencode_plugin_impl_test.dart` | no changes |
| 8 | keep | `opencode_repository_test.dart` | no changes |
| 9 | keep | `opencode_service_test.dart` | no changes |
| 10 | keep | `plugin_model_mapper_attachment_test.dart` | no changes |
| 11 | keep | `provider_mapper_test.dart` | no changes |
| 12 | keep | `runtime/open_code_bridge_plugin_test.dart` | no changes |
| 13 | keep | `runtime/open_code_ownership_record_test.dart` | no changes |
| 14 | keep | `runtime/open_code_plugin_descriptor_availability_test.dart` | no changes |
| 15 | keep | `runtime/open_code_plugin_descriptor_test.dart` | no changes |
| 16 | keep | `runtime/open_code_runtime_manifest_test.dart` | no changes |
| 17 | keep | `runtime/open_code_runtime_policy_test.dart` | no changes |
| 18 | keep | `runtime/open_code_status_reporter_test.dart` | no changes |
| 19 | keep | `sse_event_mapper_test.dart` | no changes |
| 20 | keep | `sse_event_parser_test.dart` | no changes |

## `bridge/sesori_plugin_runtime` (10)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `host_json_runtime_ownership_repository_test.dart` | no changes |
| 2 | keep | `managed_process_service_intent_test.dart` | no changes |
| 3 | keep | `managed_process_service_start_test.dart` | no changes |
| 4 | keep | `managed_process_service_test.dart` | no changes |
| 5 | keep | `managed_runtime_monitor_test.dart` | no changes |
| 6 | keep | `provisioning/managed_runtime_cleaner_test.dart` | no changes |
| 7 | keep | `provisioning/managed_runtime_provision_service_test.dart` | no changes |
| 8 | keep | `provisioning/runtime_install_service_test.dart` | no changes |
| 9 | keep | `provisioning/runtime_version_validator_test.dart` | no changes |
| 10 | keep | `runtime_restart_policy_test.dart` | no changes |

## `client/app` (98)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `capabilities/media/composer_image_picker_test.dart` | - |
| 2 | keep | `capabilities/relay/crypto/relay_crypto_service_test.dart` | - |
| 3 | keep | `capabilities/relay/protocol/relay_messages_test.dart` | - |
| 4 | cleaned | `capabilities/relay/relay_client_test.dart` | 7 tautological tests (payload-discriminator constants, enum member self-checks) |
| 5 | keep | `capabilities/relay/room_key_storage_test.dart` | - |
| 6 | keep | `capabilities/server_connection/connection_service_test.dart` | - |
| 7 | keep | `capabilities/server_connection/server_connection_config_test.dart` | - |
| 8 | keep | `capabilities/server_connection/sse_event_test.dart` | - |
| 9 | keep | `capabilities/voice/audio_format_config_test.dart` | - |
| 10 | keep | `capabilities/voice/recording_file_provider_test.dart` | - |
| 11 | keep | `capabilities/voice/voice_api_test.dart` | - |
| 12 | keep | `capabilities/voice/voice_transcription_service_test.dart` | - |
| 13 | keep | `components/navigation/prego_nav_leading_title_test.dart` | - |
| 14 | keep | `components/navigation/prego_nav_title_test.dart` | - |
| 15 | keep | `components/navigation/prego_top_navigation_test.dart` | - |
| 16 | keep | `core/api/client/http_client_test.dart` | - |
| 17 | keep | `core/api/client/relay_http_client_test.dart` | - |
| 18 | cleaned | `core/api/converters/http_method_converter_test.dart` | 5 redundant round-trip tests (fully covered by exhaustive fromJson/toJson groups) |
| 19 | speedup | `core/concurrency/concurrent_cache_test.dart` | 4 tests with real 120-200ms delays; fakeAsync elapse |
| 20 | keep | `core/concurrency/message_queue_test.dart` | - |
| 21 | keep | `core/di/firebase_dependency_registration_test.dart` | - |
| 22 | keep | `core/extensions/build_context_x_test.dart` | - |
| 23 | keep | `core/external_link_test.dart` | - |
| 24 | keep | `core/legal_links_test.dart` | - |
| 25 | keep | `core/platform/crashlytics_failure_reporter_test.dart` | - |
| 26 | keep | `core/platform/desktop_file_image_saver_test.dart` | - |
| 27 | keep | `core/platform/firebase_analytics_client_test.dart` | - |
| 28 | keep | `core/platform/firebase_analytics_configuration_test.dart` | - |
| 29 | keep | `core/platform/firebase_analytics_identity_migration_test.dart` | - |
| 30 | keep | `core/platform/firebase_push_messaging_source_test.dart` | - |
| 31 | keep | `core/platform/flutter_image_clipboard_test.dart` | - |
| 32 | keep | `core/platform/flutter_image_sharer_test.dart` | - |
| 33 | keep | `core/platform/flutter_local_notification_client_test.dart` | - |
| 34 | keep | `core/platform/mobile_photo_image_saver_test.dart` | - |
| 35 | keep | `core/platform/temporary_directory_client_test.dart` | - |
| 36 | keep | `core/routing/adaptive_session_route_matrix_test.dart` | - |
| 37 | keep | `core/routing/app_route_test.dart` | - |
| 38 | keep | `core/routing/deep_link_service_test.dart` | - |
| 39 | keep | `core/routing/imperative_pane_route_test.dart` | - |
| 40 | keep | `core/widgets/agent_model_buttons_test.dart` | - |
| 41 | keep | `core/widgets/command_picker_sheet_test.dart` | - |
| 42 | keep | `core/widgets/connection_banner_test.dart` | - |
| 43 | keep | `core/widgets/connection_graphic_test.dart` | - |
| 44 | keep | `core/widgets/connection_overlay_cubit_test.dart` | - |
| 45 | keep | `core/widgets/markdown_styles_test.dart` | - |
| 46 | keep | `core/widgets/model_picker_sheet_test.dart` | - |
| 47 | keep | `core/widgets/session_split/session_split_shell_app_bar_test.dart` | - |
| 48 | keep | `core/widgets/session_split/session_split_shell_test.dart` | - |
| 49 | keep | `features/login/email_login_sheet_test.dart` | - |
| 50 | keep | `features/login/login_cubit_test.dart` | - |
| 51 | keep | `features/login/login_provider_buttons_test.dart` | - |
| 52 | deleted | `features/login/login_screen_test.dart` | vacuous placeholder test (expect(true,isTrue)) with unused mocks; coverage lives in login_cubit_test |
| 53 | keep | `features/new_session/new_session_screen_test.dart` | - |
| 54 | keep | `features/project_list/add_project_dialog_test.dart` | - |
| 55 | keep | `features/project_list/bridge_offline_disclosure_animation_test.dart` | - |
| 56 | keep | `features/project_list/bridge_offline_view_test.dart` | - |
| 57 | keep | `features/project_list/connected_empty_view_test.dart` | - |
| 58 | keep | `features/project_list/onboarding_analytics_test.dart` | - |
| 59 | keep | `features/project_list/project_list_banner_suppression_test.dart` | - |
| 60 | keep | `features/project_list/project_list_nav_bar_test.dart` | - |
| 61 | keep | `features/project_list/project_tile_display_test.dart` | - |
| 62 | keep | `features/project_list/project_tile_menu_test.dart` | - |
| 63 | keep | `features/project_list/project_tile_states_test.dart` | - |
| 64 | keep | `features/project_list/project_tile_swipe_test.dart` | - |
| 65 | keep | `features/session_detail/adaptive_session_detail_routing_test.dart` | - |
| 66 | cleaned | `features/session_detail/session_detail_cubit_test.dart` | restored 2 long-skipped blocTests (added missing initial-load emission to expect lists); 43 pass |
| 67 | keep | `features/session_detail/session_detail_title_hydration_test.dart` | - |
| 68 | keep | `features/session_detail/widgets/adaptive_child_session_navigation_test.dart` | - |
| 69 | keep | `features/session_detail/widgets/assistant_message_card_test.dart` | - |
| 70 | keep | `features/session_detail/widgets/file_part_widget_test.dart` | - |
| 71 | keep | `features/session_detail/widgets/message_timestamp_reveal_test.dart` | - |
| 72 | keep | `features/session_detail/widgets/permission_modal_test.dart` | - |
| 73 | keep | `features/session_detail/widgets/question_modal_test.dart` | - |
| 74 | keep | `features/session_detail/widgets/reasoning_modal_test.dart` | - |
| 75 | keep | `features/session_detail/widgets/reasoning_part_card_test.dart` | - |
| 76 | keep | `features/session_detail/widgets/scroll_follow_tracker_test.dart` | - |
| 77 | keep | `features/session_detail/widgets/session_detail_body_test.dart` | - |
| 78 | keep | `features/session_detail/widgets/session_detail_message_list_test.dart` | - |
| 79 | keep | `features/session_diffs/session_diffs_collapse_scroll_test.dart` | - |
| 80 | keep | `features/session_diffs/utils/binary_detector_test.dart` | - |
| 81 | keep | `features/session_diffs/utils/diff_highlighter_test.dart` | - |
| 82 | keep | `features/session_diffs/widgets/diff_file_widget_test.dart` | - |
| 83 | keep | `features/session_diffs/widgets/diff_hunk_widget_test.dart` | - |
| 84 | keep | `features/session_diffs/widgets/diff_line_widget_test.dart` | - |
| 85 | keep | `features/session_list/adaptive_session_list_navigation_test.dart` | - |
| 86 | keep | `features/session_list/session_archived_empty_state_test.dart` | - |
| 87 | keep | `features/session_list/session_empty_state_test.dart` | - |
| 88 | keep | `features/session_list/session_lifecycle_ui_test.dart` | - |
| 89 | keep | `features/session_list/session_list_bar_test.dart` | - |
| 90 | keep | `features/session_list/session_list_panel_test.dart` | - |
| 91 | keep | `features/session_list/session_tile_menu_test.dart` | - |
| 92 | keep | `features/session_list/session_tile_states_test.dart` | - |
| 93 | keep | `features/session_list/session_tile_swipe_test.dart` | - |
| 94 | keep | `features/settings/harnesses_settings_screen_test.dart` | - |
| 95 | keep | `features/settings/notification_settings_screen_test.dart` | - |
| 96 | keep | `features/settings/settings_screen_test.dart` | - |
| 97 | keep | `main_startup_notification_wiring_test.dart` | - |
| 98 | keep | `widget_test.dart` | - |

## `client/desktop` (5)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `app_smoke_test.dart` | no changes |
| 2 | keep | `core/di/injection_test.dart` | no changes |
| 3 | keep | `core/platform/desktop_oauth_device_descriptor_provider_test.dart` | no changes |
| 4 | keep | `features/auth_gate/auth_gate_view_test.dart` | no changes |
| 5 | keep | `features/login/login_view_test.dart` | no changes |

## `client/module_auth` (6)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `auth_config_test.dart` | no changes |
| 2 | keep | `auth_manager_test.dart` | no changes |
| 3 | keep | `client/authenticated_http_api_client_test.dart` | no changes |
| 4 | keep | `client/http_api_client_get_text_test.dart` | no changes |
| 5 | keep | `client/http_api_client_put_test.dart` | no changes |
| 6 | keep | `storage/token_storage_service_test.dart` | no changes |

## `client/module_core` (98)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `api/bridge_api_test.dart` | no changes |
| 2 | keep | `api/bridge_settings_api_test.dart` | no changes |
| 3 | keep | `api/filesystem_api_test.dart` | no changes |
| 4 | keep | `api/message_image_api_test.dart` | no changes |
| 5 | keep | `api/notification_api_test.dart` | no changes |
| 6 | keep | `api/notification_preferences_api_test.dart` | no changes |
| 7 | keep | `api/notification_preferences_device_id_storage_test.dart` | no changes |
| 8 | keep | `api/plugin_api_test.dart` | no changes |
| 9 | keep | `api/plugin_preference_api_test.dart` | no changes |
| 10 | keep | `api/product_analytics_preference_api_test.dart` | no changes |
| 11 | keep | `api/product_analytics_preference_storage_test.dart` | no changes |
| 12 | keep | `api/project_api_test.dart` | no changes |
| 13 | keep | `api/project_view_api_test.dart` | no changes |
| 14 | keep | `api/session_api_test.dart` | no changes |
| 15 | keep | `capabilities/connection_service_stale_test.dart` | no changes |
| 16 | keep | `capabilities/relay/relay_client_connection_error_test.dart` | no changes |
| 17 | keep | `capabilities/relay/relay_client_handshake_replay_test.dart` | no changes |
| 18 | keep | `capabilities/relay/relay_client_socket_message_snapshot_test.dart` | no changes |
| 19 | keep | `capabilities/server_connection/connection_service_auth_state_test.dart` | no changes |
| 20 | keep | `capabilities/server_connection/connection_service_reconnect_test.dart` | no changes |
| 21 | keep | `capabilities/server_connection/connection_service_sse_test.dart` | no changes |
| 22 | keep | `capabilities/server_connection/models/sse_event_test.dart` | no changes |
| 23 | keep | `capabilities/session/session_service_test.dart` | no changes |
| 24 | keep | `consumers/analytics/session_activity_analytics_listener_test.dart` | no changes |
| 25 | keep | `cubits/appearance/appearance_cubit_test.dart` | no changes |
| 26 | keep | `cubits/bridge_identity/bridge_identity_cubit_test.dart` | no changes |
| 27 | keep | `cubits/chat_input_mode/chat_input_mode_cubit_test.dart` | no changes |
| 28 | keep | `cubits/image_attachment_actions/image_attachment_actions_cubit_test.dart` | no changes |
| 29 | keep | `cubits/legal/legal_document_cubit_test.dart` | no changes |
| 30 | cleaned | `cubits/login/login_cubit_test.dart` | deleted 2 duplicated blocTests |
| 31 | keep | `cubits/message_image/message_image_cubit_test.dart` | no changes |
| 32 | keep | `cubits/new_session/new_session_cubit_test.dart` | no changes |
| 33 | keep | `cubits/new_session/new_session_plugin_selection_test.dart` | no changes |
| 34 | keep | `cubits/notification_preferences/notification_preferences_cubit_test.dart` | no changes |
| 35 | keep | `cubits/plugin_management/plugin_management_cubit_test.dart` | no changes |
| 36 | keep | `cubits/product_analytics_preference/product_analytics_preference_cubit_test.dart` | no changes |
| 37 | keep | `cubits/project_list/project_list_cubit_test.dart` | no changes |
| 38 | keep | `cubits/pull_request_refresh_settings/pull_request_refresh_settings_cubit_test.dart` | no changes |
| 39 | keep | `cubits/session_detail/prompt_send_queue_test.dart` | no changes |
| 40 | keep | `cubits/session_detail/session_detail_cubit_permission_test.dart` | no changes |
| 41 | keep | `cubits/session_detail/session_detail_event_buffer_test.dart` | no changes |
| 42 | keep | `cubits/session_detail/session_detail_reconnect_test.dart` | no changes |
| 43 | keep | `cubits/session_detail/session_detail_stale_test.dart` | no changes |
| 44 | keep | `cubits/session_detail/streaming_text_buffer_test.dart` | no changes |
| 45 | keep | `cubits/session_diffs/diff_cubit_test.dart` | no changes |
| 46 | keep | `cubits/session_list/session_list_cubit_test.dart` | no changes |
| 47 | keep | `cubits/settings/settings_cubit_test.dart` | no changes |
| 48 | keep | `cubits/splash/splash_cubit_test.dart` | no changes |
| 49 | keep | `cubits/state_defaults_test.dart` | no changes |
| 50 | keep | `errors/remote_failure_reason_test.dart` | no changes |
| 51 | keep | `foundation/composer_draft_test.dart` | no changes |
| 52 | keep | `foundation/product_analytics_event_test.dart` | no changes |
| 53 | keep | `repositories/analytics_repository_test.dart` | no changes |
| 54 | keep | `repositories/appearance_store_test.dart` | no changes |
| 55 | keep | `repositories/bridge_repository_test.dart` | no changes |
| 56 | keep | `repositories/chat_input_mode_store_test.dart` | no changes |
| 57 | keep | `repositories/composer_draft_repository_test.dart` | no changes |
| 58 | keep | `repositories/message_image_repository_test.dart` | no changes |
| 59 | keep | `repositories/models/repo_provider_test.dart` | no changes |
| 60 | keep | `repositories/notification_preferences_repository_test.dart` | no changes |
| 61 | keep | `repositories/plugin_preference_repository_test.dart` | - |
| 62 | keep | `repositories/plugin_repository_test.dart` | - |
| 63 | keep | `repositories/product_analytics_preference_repository_test.dart` | - |
| 64 | keep | `repositories/project_repository_test.dart` | - |
| 65 | keep | `repositories/project_view_repository_test.dart` | - |
| 66 | keep | `repositories/pull_request_refresh_settings_repository_test.dart` | - |
| 67 | keep | `repositories/registered_bridges_store_test.dart` | - |
| 68 | keep | `repositories/session_repository_test.dart` | - |
| 69 | keep | `routing/analytics_route_listener_test.dart` | - |
| 70 | keep | `routing/app_routes_test.dart` | - |
| 71 | keep | `routing/notification_open_dispatcher_test.dart` | - |
| 72 | keep | `services/composer_draft_calculator_test.dart` | - |
| 73 | keep | `services/foreground_notification_dispatcher_test.dart` | - |
| 74 | keep | `services/installation_analytics_service_test.dart` | - |
| 75 | keep | `services/models/new_session_backend_scope_test.dart` | - |
| 76 | keep | `services/models/product_analytics_preference_snapshot_test.dart` | - |
| 77 | keep | `services/new_session_options_service_test.dart` | - |
| 78 | keep | `services/new_session_plugin_service_test.dart` | - |
| 79 | keep | `services/new_session_selection_tracker_test.dart` | - |
| 80 | keep | `services/notification_preferences_service_test.dart` | - |
| 81 | keep | `services/notification_registration_service_test.dart` | - |
| 82 | keep | `services/plugin_management_service_test.dart` | - |
| 83 | keep | `services/product_analytics_service_test.dart` | - |
| 84 | keep | `services/project_list_service_test.dart` | - |
| 85 | keep | `services/project_viewing_service_test.dart` | - |
| 86 | keep | `services/pull_request_refresh_settings_service_test.dart` | - |
| 87 | keep | `services/registered_bridges_service_test.dart` | - |
| 88 | keep | `services/session_detail_load_service_test.dart` | - |
| 89 | keep | `services/session_list_service_test.dart` | - |
| 90 | keep | `services/session_unseen_tracker_test.dart` | - |
| 91 | keep | `services/session_viewing_service_test.dart` | - |
| 92 | keep | `services/slash_command_service_test.dart` | - |
| 93 | speedup | `services/sse_event_tracker_test.dart` | 8x Future.delayed(10ms) real waits; replace with microtask pumps |
| 94 | keep | `utils/command_filter/command_picker_entry_builder_test.dart` | - |
| 95 | keep | `utils/diff/diff_engine_test.dart` | - |
| 96 | keep | `utils/diff/language_detector_test.dart` | - |
| 97 | keep | `utils/model_filter/default_model_selector_test.dart` | - |
| 98 | keep | `utils/model_filter/model_picker_section_builder_test.dart` | - |

## `client/module_desktop_core` (6)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `control/control_message_dispatcher_test.dart` | no changes |
| 2 | keep | `cubits/auth_gate/auth_gate_cubit_test.dart` | no changes |
| 3 | keep | `di/injection_test.dart` | no changes |
| 4 | keep | `foundation/control_channel_server_test.dart` | no changes |
| 5 | keep | `trackers/bridge_prompt_tracker_test.dart` | no changes |
| 6 | keep | `trackers/bridge_status_tracker_test.dart` | no changes |

## `client/module_prego` (20)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `components/prego_activity_indicator_test.dart` | no changes |
| 2 | keep | `components/prego_ai_loader_test.dart` | no changes |
| 3 | keep | `components/prego_anchor_menu_test.dart` | no changes |
| 4 | keep | `components/prego_animated_sliver_list_test.dart` | no changes |
| 5 | keep | `components/prego_bottom_sheet_test.dart` | no changes |
| 6 | keep | `components/prego_brand_logo_test.dart` | no changes |
| 7 | keep | `components/prego_glass_scaffold_banner_test.dart` | no changes |
| 8 | keep | `components/prego_glass_scaffold_fab_test.dart` | no changes |
| 9 | keep | `components/prego_glass_scaffold_status_bar_test.dart` | no changes |
| 10 | keep | `components/prego_grouped_rows_test.dart` | no changes |
| 11 | keep | `components/prego_info_popover_test.dart` | no changes |
| 12 | keep | `components/prego_input_field_test.dart` | no changes |
| 13 | keep | `components/prego_picker_button_test.dart` | no changes |
| 14 | keep | `components/prego_popover_test.dart` | no changes |
| 15 | keep | `components/prego_skeleton_test.dart` | no changes |
| 16 | keep | `components/prego_surfaces_test.dart` | no changes |
| 17 | keep | `components/prego_switch_test.dart` | no changes |
| 18 | keep | `components/prego_tag_test.dart` | no changes |
| 19 | keep | `components/prego_voice_waveform_test.dart` | no changes |
| 20 | keep | `interactions/prego_swipe_actions_test.dart` | no changes |

## `shared/no_slop_linter` (22)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `fixes/add_return_type_fix_test.dart` | linter rule matrix; no changes |
| 2 | keep | `fixes/dartz_tuple_to_record_fix_test.dart` | linter rule matrix; no changes |
| 3 | keep | `fixes/exhaustive_switch_fix_test.dart` | linter rule matrix; no changes |
| 4 | keep | `fixes/required_named_parameters_fix_test.dart` | linter rule matrix; no changes |
| 5 | keep | `rules/avoid_as_cast_test.dart` | linter rule matrix; no changes |
| 6 | keep | `rules/avoid_bang_operator_test.dart` | linter rule matrix; no changes |
| 7 | keep | `rules/avoid_dartz_tuple_test.dart` | linter rule matrix; no changes |
| 8 | keep | `rules/avoid_dynamic_return_type_test.dart` | linter rule matrix; no changes |
| 9 | keep | `rules/avoid_hardcoded_colors_test.dart` | linter rule matrix; no changes |
| 10 | keep | `rules/avoid_hardcoded_text_styles_test.dart` | linter rule matrix; no changes |
| 11 | keep | `rules/avoid_implicit_tostring_test.dart` | linter rule matrix; no changes |
| 12 | keep | `rules/avoid_mutable_class_fields_test.dart` | linter rule matrix; no changes |
| 13 | keep | `rules/avoid_navigator_of_test.dart` | linter rule matrix; no changes |
| 14 | keep | `rules/avoid_raw_go_router_test.dart` | linter rule matrix; no changes |
| 15 | keep | `rules/avoid_string_literals_in_widgets_test.dart` | linter rule matrix; no changes |
| 16 | keep | `rules/prefer_edge_insets_directional_test.dart` | linter rule matrix; no changes |
| 17 | keep | `rules/prefer_exhaustive_switch_test.dart` | linter rule matrix; no changes |
| 18 | keep | `rules/prefer_required_named_parameters_test.dart` | linter rule matrix; no changes |
| 19 | keep | `rules/prefer_size_const_test.dart` | linter rule matrix; no changes |
| 20 | keep | `rules/prefer_specific_type_test.dart` | linter rule matrix; no changes |
| 21 | keep | `rules/prefer_text_align_directional_test.dart` | linter rule matrix; no changes |
| 22 | keep | `test_utils/analysis_rule_fix_test.dart` | linter rule matrix; no changes |

## `shared/sesori_shared` (38)

| # | status | file | note |
|---|---|---|---|
| 1 | keep | `auth/jwt_claims_test.dart` | no changes |
| 2 | keep | `concurrency/concurrent_cache_test.dart` | reviewed: no changes |
| 3 | keep | `concurrency/event_queue_test.dart` | reviewed: no changes |
| 4 | keep | `concurrency/future_x_test.dart` | reviewed: no changes |
| 5 | keep | `crypto/crypto_test.dart` | no changes |
| 6 | keep | `extensions/iterable_x_test.dart` | reviewed: no changes |
| 7 | keep | `extensions/sugar_dart_test.dart` | reviewed: no changes |
| 8 | keep | `models/auth_device_info_builder_test.dart` | wire-contract; no changes |
| 9 | keep | `models/auth_flow_models_test.dart` | wire-contract round-trips; no changes |
| 10 | keep | `models/base_branch_response_test.dart` | no changes |
| 11 | keep | `models/bridge_setting_update_test.dart` | wire-contract; no changes |
| 12 | keep | `models/bridge_summary_test.dart` | wire-contract round-trips; no changes |
| 13 | keep | `models/catalog_import_models_test.dart` | wire-contract; no changes |
| 14 | keep | `models/message_attachment_test.dart` | wire-contract; no changes |
| 15 | keep | `models/plugin_id_compatibility_test.dart` | wire-contract; no changes |
| 16 | keep | `models/plugin_management_contract_test.dart` | wire-contract round-trips; no changes |
| 17 | keep | `models/plugin_runtime_contract_test.dart` | wire-contract; no changes |
| 18 | keep | `models/project_management_models_test.dart` | wire-contract; no changes |
| 19 | keep | `models/pull_request_history_compatibility_test.dart` | wire-contract; no changes |
| 20 | cleaned | `models/pull_request_info_test.dart` | deleted 2 vacuous constructor-getter tests |
| 21 | keep | `models/pull_request_refresh_settings_test.dart` | wire-contract; no changes |
| 22 | keep | `models/register_bridge_request_test.dart` | wire-contract round-trips; no changes |
| 23 | cleaned | `models/reply_to_permission_request_test.dart` | deleted vacuous constructor test |
| 24 | cleaned | `models/sesori_sse_event_sessions_updated_test.dart` | deleted vacuous constructor test |
| 25 | keep | `models/sesori_sse_event_test.dart` | wire-contract; no changes |
| 26 | keep | `models/session_branch_name_test.dart` | wire-contract; no changes |
| 27 | keep | `models/session_has_worktree_test.dart` | no changes |
| 28 | keep | `models/session_options_response_test.dart` | wire-contract; no changes |
| 29 | keep | `models/session_prompt_defaults_test.dart` | wire-contract; no changes |
| 30 | keep | `models/session_variant_request_test.dart` | wire-contract; no changes |
| 31 | keep | `notifications/session_notification_id_test.dart` | reviewed: no changes |
| 32 | keep | `protocol/close_codes_test.dart` | wire-contract round-trips; no changes |
| 33 | keep | `protocol/control_message_test.dart` | wire-contract round-trips; no changes |
| 34 | keep | `protocol/control_provision_progress_test.dart` | reviewed: no changes |
| 35 | keep | `protocol/framing_test.dart` | wire-contract round-trips; no changes |
| 36 | keep | `protocol/relay_auth_message_test.dart` | reviewed: no changes |
| 37 | keep | `protocol/relay_project_view_test.dart` | wire-contract round-trips; no changes |
| 38 | keep | `streams/ref_count_reusable_stream_test.dart` | no changes |

