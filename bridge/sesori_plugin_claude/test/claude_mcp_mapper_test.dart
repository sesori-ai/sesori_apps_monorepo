import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const scope = PluginMcpSessionScope(sessionId: "native-session");
  PluginMcpServerSnapshot map(Map<String, dynamic> server) =>
      const ClaudeMcpMapper()
              .map(
                status: ClaudeMcpStatusDto.fromJson({
                  "mcpServers": [server],
                }),
                scope: scope,
              )
              .entries
              .single
          as PluginMcpServerSnapshot;

  test("projects safe origin and friendly metadata without changing native identity", () {
    final server = map({
      "name": "opaque-key",
      "status": "connected",
      "scope": "managed",
      "serverInfo": {"title": " Friendly server ", "description": " "},
      "config": {
        "type": "http",
        "url": "https://user:secret@example.com:8443/private?token=secret#fragment",
        "headers": {"Authorization": "secret"},
        "env": {"TOKEN": "secret"},
      },
      "tools": [
        {"name": "echo", "description": " Echo a value "},
      ],
    });
    expect(server.name, "Friendly server");
    expect(server.target.serverKey, "opaque-key");
    expect(server.target.scope, same(scope));
    expect(server.description, isNull);
    expect(server.endpointOrigin, "https://example.com:8443");
    expect(server.authorization, PluginMcpAuthorizationState.unknown);
    expect(server.configuration!.mutability, PluginMcpConfigurationMutability.readOnly);
    expect((server.tools as PluginMcpToolsAvailable).tools.single.description, "Echo a value");
  });

  test("stdio credentials are not inferred from transport", () {
    final server = map({
      "name": "fixture", "status": "connected", "config": {"type": "stdio", "env": {"TOKEN": "fixture-secret"}},
    });
    expect(server.authorization, PluginMcpAuthorizationState.unknown);
  });

  test("keeps empty, unavailable, failed and cached tools distinct", () {
    expect(
      map({"name": "a", "status": "connected", "tools": <Map<String, dynamic>>[]}).tools,
      isA<PluginMcpToolsAvailable>(),
    );
    expect(map({"name": "a", "status": "connected"}).tools, isA<PluginMcpToolsUnavailable>());
    expect(
      map({"name": "a", "status": "pending", "tools": <Map<String, dynamic>>[]}).tools,
      isA<PluginMcpToolsUnavailable>(),
    );
    expect(
      map({"name": "a", "status": "failed", "tools": <Map<String, dynamic>>[]}).tools,
      isA<PluginMcpToolsFailed>(),
    );
    final cached = map({
      "name": "a",
      "status": "failed",
      "tools": [
        {"name": "echo"},
      ],
    });
    expect(cached.connection, isA<PluginMcpConnectionFailed>());
    expect(cached.tools, isA<PluginMcpToolsAvailable>());
  });

  test("handles unknown native states and rejects non-network endpoint origins", () {
    final unknown = map({
      "name": "a",
      "status": "new-native-state",
      "scope": "new-scope",
      "config": {"type": "new-transport", "url": "file:///private/config"},
    });
    expect((unknown.connection as PluginMcpConnectionStatus).phase, PluginMcpConnectionPhase.unknown);
    expect(unknown.authorization, PluginMcpAuthorizationState.unknown);
    expect(unknown.configuration, isNull);
    expect(unknown.endpointOrigin, isNull);
    final auth = map({"name": "a", "status": "needs-auth", "tools": <Map<String, dynamic>>[]});
    expect(auth.authorization, PluginMcpAuthorizationState.required);
    expect(auth.tools, isA<PluginMcpToolsUnavailable>());
  });
}
