import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Builds the owner-only TypeScript extension used by one resident Pi child.
final class const PiAgentToolExtensionSource() {
  String build({required PluginAgentToolMcpCapability capability}) {
    final registrations = pluginAgentToolDefinitions.map(_registration).join("\n\n");
    return '''
import { Type } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const endpoint = ${jsonEncode(capability.url)};
const bearerToken = ${jsonEncode(capability.bearerToken)};
let nextRequestId = 0;

type McpResponse = {
  result?: {
    content?: Array<{ type: "text"; text: string }>;
    structuredContent?: unknown;
  };
  error?: { code?: number };
};

async function callTool(
  name: string,
  args: Record<string, unknown>,
  signal: AbortSignal | undefined,
) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Authorization": "Bearer " + bearerToken,
      "Content-Type": "application/json",
      "MCP-Protocol-Version": "2025-06-18",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: ++nextRequestId,
      method: "tools/call",
      params: { name, arguments: args },
    }),
    signal,
  });
  if (!response.ok) {
    throw new Error("Device Canvas request failed (HTTP " + response.status + ")");
  }
  const payload = (await response.json()) as McpResponse;
  if (payload.error) {
    throw new Error("Device Canvas request failed (MCP " + (payload.error.code ?? "unknown") + ")");
  }
  if (!payload.result) {
    throw new Error("Device Canvas returned no tool result");
  }
  return {
    content: payload.result.content ?? [{
      type: "text" as const,
      text: JSON.stringify(payload.result.structuredContent ?? {}),
    }],
    details: payload.result.structuredContent,
  };
}

export default function (pi: ExtensionAPI) {
$registrations
}
''';
  }

  String _registration(PluginAgentToolDefinition definition) =>
      '''
  pi.registerTool({
    name: ${jsonEncode(definition.tool.wireName)},
    label: ${jsonEncode(_label(definition.tool))},
    description: ${jsonEncode(definition.description)},
    parameters: ${_parameters(definition)},
    async execute(_toolCallId, params, signal) {
      return callTool(${jsonEncode(definition.tool.wireName)}, params, signal);
    },
  });''';

  String _parameters(PluginAgentToolDefinition definition) {
    final properties = definition.inputSchema["properties"];
    if (properties is Map && properties.isEmpty) {
      return "Type.Object({}, { additionalProperties: false })";
    }
    if (properties is! Map || properties.keys.toSet().difference(const {"deviceKey"}).isNotEmpty) {
      throw StateError("Unsupported Device Canvas tool schema");
    }
    final deviceKey = properties["deviceKey"];
    if (deviceKey is! Map) throw StateError("Unsupported Device Canvas device key schema");
    final options = <String, Object?>{
      "minLength": deviceKey["minLength"],
      "maxLength": deviceKey["maxLength"],
      "description": deviceKey["description"],
    };
    return "Type.Object({ deviceKey: Type.String(${jsonEncode(options)}) }, { additionalProperties: false })";
  }

  String _label(PluginAgentTool tool) => switch (tool) {
    PluginAgentTool.listSimulators => "List Simulators",
    PluginAgentTool.claimSimulator => "Claim Simulator",
    PluginAgentTool.releaseSimulator => "Release Simulator",
  };
}
