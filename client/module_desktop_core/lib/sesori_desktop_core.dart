/// Desktop business logic for Sesori — bridge supervision, control-channel
/// orchestration, and desktop cubits. Pure Dart, no Flutter dependency.
library;

// The signed-in account carried by AuthGateState (move + re-export pattern,
// so shell consumers don't need a direct sesori_shared import for it).
export "package:sesori_shared/sesori_shared.dart" show AuthUser, BridgeSupervisedExitCode;

export "src/api/bridge_id_storage.dart";
export "src/api/bridge_process_api.dart";
export "src/api/bridge_process_log_storage.dart";
export "src/api/control_channel_api.dart";
export "src/api/desktop_instance_api.dart";
export "src/api/desktop_instance_storage.dart";
export "src/control/control_message_dispatcher.dart";
export "src/cubits/auth_gate/auth_gate_cubit.dart";
export "src/cubits/auth_gate/auth_gate_state.dart";
export "src/cubits/bridge_control/bridge_control_cubit.dart";
export "src/cubits/bridge_control/bridge_control_state.dart";
export "src/di/injection.dart";
export "src/foundation/bridge_process_desired_state.dart";
export "src/foundation/control_channel_server.dart";
export "src/foundation/platform/bridge_executable_path_resolver.dart";
export "src/foundation/platform/desktop_application_support_directory.dart";
export "src/foundation/platform/desktop_application_terminator.dart";
export "src/foundation/platform/launch_at_login.dart";
export "src/foundation/platform/system_tray.dart";
export "src/foundation/platform/window_host.dart";
export "src/orchestration/desktop_logout_orchestrator.dart";
export "src/orchestration/desktop_startup_orchestrator.dart";
export "src/repositories/bridge_process_log_repository.dart";
export "src/repositories/bridge_process_repository.dart";
export "src/repositories/control_command_repository.dart";
export "src/repositories/desktop_instance_repository.dart";
export "src/services/bridge_process_service.dart";
export "src/services/bridge_process_state.dart";
export "src/services/control_command_service.dart";
export "src/services/desktop_instance_service.dart";
export "src/trackers/bridge_control_status.dart";
export "src/trackers/bridge_process_log_tracker.dart";
export "src/trackers/bridge_prompt_tracker.dart";
export "src/trackers/bridge_status_tracker.dart";
export "src/trackers/desktop_logout_tracker.dart";
