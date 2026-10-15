import "models/plugin_mcp.dart";
import "models/plugin_mcp_connector_setup.dart";

/// Optional catalog setup handoff. Resolve an existing offer in its exact native
/// scope without connecting/resuming sessions, installing, authenticating or
/// writing configuration. Destinations remain request-scoped, never inventory.
abstract interface class McpConnectorSetupPluginApi() {
  Future<PluginMcpConnectorSetupResult> resolveMcpConnectorSetup({required PluginMcpConnectorOfferTarget target});
}
