/// Protocol primitives for the Pi Agent Harness bridge plugin.
///
/// The package is intentionally not registered with the bridge app until the
/// complete plugin is available.
library;

export "src/api/models/pi_assistant_delta.dart";
export "src/api/models/pi_event.dart";
export "src/api/models/pi_extension_ui_request.dart";
export "src/api/models/pi_rpc_frame.dart";
export "src/api/pi_launch_spec.dart";
export "src/api/pi_process_factory.dart";
export "src/api/pi_rpc_client.dart";
export "src/api/pi_session_storage_api.dart";
export "src/models/pi_assistant_stop_reason.dart";
export "src/models/pi_compaction_reason.dart";
export "src/models/pi_notification_type.dart";
export "src/models/pi_rpc_command.dart";
export "src/models/pi_summarization_source.dart";
export "src/models/pi_thinking_level.dart";
export "src/pi_plugin_impl.dart";
export "src/repositories/pi_backend_catalog_repository.dart";
export "src/repositories/pi_session_catalog_repository.dart";
export "src/services/pi_catalog_service.dart";
export "src/trackers/pi_catalog_tracker.dart";
