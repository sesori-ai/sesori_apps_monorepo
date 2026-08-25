/// Local protocol shared by the bridge and backend adapters that expose Device
/// Canvas ownership as native agent tools.
const int deviceCanvasAgentToolProtocolVersion = 1;

/// Bridge-internal bootstrap credential supplied only after local server start.
const String deviceCanvasAgentToolBootstrapSecretEnvironment = "SESORI_DEVICE_CANVAS_AGENT_TOOL_BOOTSTRAP_SECRET";

/// Owner-only one-time credential file exposed to a managed backend process.
const String deviceCanvasAgentToolBootstrapFileEnvironment = "SESORI_DEVICE_CANVAS_AGENT_TOOL_BOOTSTRAP_FILE";

/// Owner-readable rendezvous path for the bridge's loopback agent-tool server.
const String deviceCanvasAgentToolRendezvousEnvironment = "SESORI_DEVICE_CANVAS_AGENT_TOOL_RENDEZVOUS";

/// Managed-state marker written only after the native tool adapter registers.
const String deviceCanvasAgentToolReadyFileEnvironment = "SESORI_DEVICE_CANVAS_AGENT_TOOL_READY_FILE";
