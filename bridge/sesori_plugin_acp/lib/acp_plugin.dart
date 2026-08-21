// Generic ACP (Agent Client Protocol) backend machinery for the Sesori bridge.
//
// Provides a reusable stdio JSON-RPC transport, a typed standard-ACP request
// surface (AcpAgentApi), protocol builders/parsers, a base session/update ->
// BridgeSseEvent mapper, a base permission registry, session/load history
// replay, and the AcpPlugin base. Concrete harnesses (cursor, hermes, omp)
// consume these and layer on their own quirks.
//
// Adding an ACP harness:
//  1. An `XxxBinary` with the launch spec (binary + `acp` args) and any fixed
//     handshake policy (auth method id, capability meta).
//  2. A subclass of AcpPlugin. Every policy and hook has a stock-ACP default;
//     override only what the agent does differently (see the AcpPlugin doc).
//     The composer builds one AcpSessionConfigurationTracker + AcpCommandTracker
//     and shares them between the AcpEventMapper (subclass the mapper only for
//     `xxx/*` notification extensions), the neutral AcpSessionOptionsService,
//     and any harness catalog service.
//  3. Catalog discovery / persisted cleanup that needs its own agent process:
//     an AcpStdioClient + AcpAgentApi (initialize, session/new, load, list,
//     set_config_option, close) wrapped in a harness-specific lease API.
//     Services write session config through AcpSessionConfigRepository, never
//     the api directly.
//  4. A descriptor whose `start` builds the plugin and returns
//     `AcpBridgePlugin.start(...)`; custom server requests go in an
//     AcpApprovalRegistry subclass via `buildApprovalRegistry`.
export "src/acp_approval_registry.dart";
export "src/acp_command_listener.dart";
export "src/acp_command_tracker.dart";
export "src/acp_event_mapper.dart";
export "src/acp_plugin.dart";
export "src/acp_process_factory.dart";
export "src/acp_protocol.dart";
export "src/acp_session_configuration_tracker.dart";
export "src/acp_session_loader.dart";
export "src/acp_session_options_service.dart";
export "src/acp_stdio_client.dart";
export "src/api/acp_agent_api.dart";
export "src/repositories/acp_session_config_repository.dart";
export "src/repositories/mappers/acp_content_mapper.dart";
// Plugin-lifecycle housing: the BridgePlugin wrapper + the host-backed process
// factory a descriptor uses to run an ACP agent under the bridge's lifecycle.
export "src/runtime/acp_bridge_plugin.dart";
export "src/runtime/host_process_acp_factory.dart";
