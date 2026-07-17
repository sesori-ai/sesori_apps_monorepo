// Generic ACP (Agent Client Protocol) backend machinery for the Sesori bridge.
//
// Provides a reusable stdio JSON-RPC transport, protocol builders/parsers, a
// base session/update -> BridgeSseEvent mapper, a base permission registry,
// session/load history replay, and a concrete AcpPlugin. Concrete harnesses
// (e.g. cursor_plugin) consume these and layer on their own quirks.
export "src/acp_approval_registry.dart";
export "src/acp_command_identity_builder.dart";
export "src/acp_command_tracker.dart";
export "src/acp_event_mapper.dart";
export "src/acp_plugin.dart";
export "src/acp_process_factory.dart";
export "src/acp_protocol.dart";
export "src/acp_session_loader.dart";
export "src/acp_stdio_client.dart";
export "src/acp_stdio_client_builder.dart";
export "src/api/acp_api.dart";
export "src/dispatchers/acp_turn_configuration_dispatcher.dart";
export "src/dispatchers/acp_turn_event_dispatcher.dart";
export "src/listeners/acp_approval_listener.dart";
export "src/listeners/acp_notification_listener.dart";
export "src/repositories/acp_message_repository.dart";
export "src/repositories/acp_notification_repository.dart";
export "src/repositories/acp_session_repository.dart";
export "src/repositories/models/acp_notification_record.dart";
// Plugin-lifecycle housing: the BridgePlugin wrapper + the host-backed process
// factory a descriptor uses to run an ACP agent under the bridge's lifecycle.
export "src/runtime/acp_bridge_plugin.dart";
export "src/runtime/host_process_acp_factory.dart";
export "src/services/acp_connection_service.dart";
export "src/services/acp_turn_service.dart";
export "src/trackers/acp_command_turn_tracker.dart";
export "src/trackers/acp_session_directory_tracker.dart";
export "src/trackers/acp_session_residency_tracker.dart";
export "src/trackers/acp_turn_queue_tracker.dart";
