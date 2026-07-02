// Generic ACP (Agent Client Protocol) backend machinery for the Sesori bridge.
//
// Provides a reusable stdio JSON-RPC transport, protocol builders/parsers, a
// base session/update -> BridgeSseEvent mapper, a base permission registry,
// session/load history replay, and a concrete AcpPlugin. Concrete harnesses
// (e.g. cursor_plugin) consume these and layer on their own quirks.
export "src/acp_approval_registry.dart";
export "src/acp_event_mapper.dart";
export "src/acp_plugin.dart";
export "src/acp_process_factory.dart";
export "src/acp_project_registry.dart";
export "src/acp_protocol.dart";
export "src/acp_session_loader.dart";
export "src/acp_stdio_client.dart";
// Plugin-lifecycle housing: the BridgePlugin wrapper + the host-backed process
// factory a descriptor uses to run an ACP agent under the bridge's lifecycle.
export "src/runtime/acp_bridge_plugin.dart";
export "src/runtime/host_process_acp_factory.dart";
