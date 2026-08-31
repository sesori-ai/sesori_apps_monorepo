/// The three bridge-owned tools an agent backend may expose.
enum PluginAgentTool(final String wireName) {
  listSimulators("list_simulators"),
  claimSimulator("claim_simulator"),
  releaseSimulator("release_simulator");

  static PluginAgentTool? fromWireName(String value) {
    for (final tool in values) {
      if (tool.wireName == value) return tool;
    }
    return null;
  }
}

class const PluginAgentToolDefinition({
  required final PluginAgentTool tool,
  required final String description,
  // ignore: no_slop_linter/prefer_specific_type, JSON Schema is heterogeneous by definition
  required final Map<String, Object?> inputSchema,
});

// ignore: no_slop_linter/prefer_specific_type, JSON Schema is heterogeneous by definition
const Map<String, Object?> _noArgumentsSchema = {
  "type": "object",
  "properties": <String, Never>{},
  "additionalProperties": false,
};

// ignore: no_slop_linter/prefer_specific_type, JSON Schema is heterogeneous by definition
const Map<String, Object?> _deviceKeyArgumentsSchema = {
  "type": "object",
  "properties": {
    "deviceKey": {
      "type": "string",
      "minLength": 1,
      "maxLength": 512,
      "description": "Device key returned by list_simulators",
    },
  },
  "required": ["deviceKey"],
  "additionalProperties": false,
};

const List<PluginAgentToolDefinition> pluginAgentToolDefinitions = [
  PluginAgentToolDefinition(
    tool: PluginAgentTool.listSimulators,
    description: "List online iOS simulators and Android emulators in Device Canvas, including whether each is unclaimed, owned by this session, or owned by another session.",
    inputSchema: _noArgumentsSchema,
  ),
  PluginAgentToolDefinition(
    tool: PluginAgentTool.claimSimulator,
    description: "Claim one online Device Canvas simulator for this session. A device owned by another session is never reassigned.",
    inputSchema: _deviceKeyArgumentsSchema,
  ),
  PluginAgentToolDefinition(
    tool: PluginAgentTool.releaseSimulator,
    description: "Release a Device Canvas simulator owned by this session.",
    inputSchema: _deviceKeyArgumentsSchema,
  ),
];

/// One opaque, session-scoped HTTP MCP capability.
class const PluginAgentToolMcpCapability({
  required final String id,
  required final String url,
  required final String bearerToken,
}) {
  @override
  String toString() => "PluginAgentToolMcpCapability(<redacted>)";
}

/// Bridge-owned tool authority bound to one plugin generation.
///
/// Native adapters pass only backend identity obtained from their trusted
/// callback. MCP adapters provision an opaque capability and never put a
/// bridge or backend session identifier in model-controlled arguments.
abstract interface class PluginAgentToolHost() {
  // ignore: no_slop_linter/prefer_specific_type, tool results are bounded JSON protocol objects
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    // ignore: no_slop_linter/prefer_specific_type, tool arguments are validated bounded JSON
    required Map<String, dynamic> arguments,
  });

  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId});

  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  });

  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability});

  /// Revokes every capability issued through this generation-scoped host.
  Future<void> dispose();
}

/// Owner-only files used to pass generated adapter configuration to a child.
abstract interface class PluginPrivateFileService() {
  Future<String> write({required String name, required String contents});

  Future<void> delete({required String name});
}

/// Optional services implemented only by the bridge's production plugin host.
abstract interface class PluginAgentToolServices() {
  PluginAgentToolHost get tools;
  PluginPrivateFileService get privateFiles;
}

/// Optional-provider marker so existing [PluginHost] implementations do not
/// need to grow agent-tool members.
abstract interface class PluginAgentToolServicesProvider() {
  PluginAgentToolServices? get agentToolServices;
}
