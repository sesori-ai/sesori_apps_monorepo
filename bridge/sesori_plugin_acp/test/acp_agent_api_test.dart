import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("AcpAgentApi.initialize", () {
    late FakeAcpProcess fake;
    late AcpStdioClient client;
    late AcpAgentApi api;

    setUp(() async {
      fake = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: ["acp"]),
        processFactory: (_) async => fake,
        logTag: "acp-test",
      );
      await client.connect();
      api = AcpAgentApi(client: client);
    });

    tearDown(() async {
      await client.dispose();
      await fake.close();
    });

    Future<Map<String, dynamic>> waitForFrame(String method) async {
      for (var i = 0; i < 400; i++) {
        final matches = fake.written.where((frame) => frame["method"] == method);
        if (matches.isNotEmpty) return matches.last;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      throw StateError("agent never wrote a '$method' frame");
    }

    Map<String, dynamic> initializeResult({required List<Map<String, dynamic>> authMethods}) => {
      "protocolVersion": 1,
      "agentCapabilities": <String, dynamic>{},
      "authMethods": authMethods,
    };

    test("picks the first non-terminal auth method when none is configured", () async {
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: null,
        authMethodAllowlist: null,
        timeout: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"type": "terminal", "id": "setup", "name": "Interactive setup"},
            {"id": "provider", "name": "Configured provider"},
          ],
        ),
      });
      final authenticate = await waitForFrame("authenticate");
      expect(authenticate["params"], {"methodId": "provider"});
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      await initializing;
    });

    test("an allowlist selects only an advertised permitted method", () async {
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: null,
        authMethodAllowlist: const {"cached_token"},
        timeout: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"id": "grok.com", "name": "Interactive login"},
            {"id": "cached_token", "name": "Cached token"},
          ],
        ),
      });
      final authenticate = await waitForFrame("authenticate");
      expect(authenticate["params"], {"methodId": "cached_token"});
      fake.emit({"jsonrpc": "2.0", "id": authenticate["id"], "result": <String, dynamic>{}});
      await initializing;
    });

    test("a rejected allowlisted method becomes a typed authentication failure", () async {
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: null,
        authMethodAllowlist: const {"cached_token"},
        timeout: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"id": "cached_token", "name": "Cached token"},
          ],
        ),
      });
      final authenticate = await waitForFrame("authenticate");
      fake.emit({
        "jsonrpc": "2.0",
        "id": authenticate["id"],
        "error": {"code": -32000, "message": "Rejected"},
      });

      await expectLater(
        initializing,
        throwsA(
          isA<PluginAuthenticationRequiredException>().having(
            (error) => error.cause,
            "cause",
            isA<AcpRpcException>(),
          ),
        ),
      );
    });

    test("an allowlist rejects an interactive-only advertised list", () async {
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: null,
        authMethodAllowlist: const {"cached_token", "xai.api_key"},
        timeout: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"id": "grok.com", "name": "Interactive login"},
          ],
        ),
      });
      await expectLater(initializing, throwsA(isA<PluginAuthenticationRequiredException>()));
      expect(fake.written.where((frame) => frame["method"] == "authenticate"), isEmpty);
    });

    test("a terminal-only agent fails typed, naming the connection", () async {
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: null,
        authMethodAllowlist: null,
        timeout: const Duration(seconds: 5),
      );
      final initialize = await waitForFrame("initialize");
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"type": "terminal", "id": "setup", "name": "Interactive setup"},
          ],
        ),
      });
      await expectLater(
        initializing,
        throwsA(
          isA<PluginAuthenticationRequiredException>().having(
            (error) => error.message,
            "message",
            contains("acp-test"),
          ),
        ),
      );
      expect(fake.written.where((frame) => frame["method"] == "authenticate"), isEmpty);
    });

    test("authenticate runs inside the same deadline as initialize", () async {
      const timeout = Duration(milliseconds: 600);
      final stopwatch = Stopwatch()..start();
      final initializing = api.initialize(
        formElicitation: false,
        capabilityMeta: null,
        authMethodId: "login",
        authMethodAllowlist: null,
        timeout: timeout,
      );
      final initialize = await waitForFrame("initialize");
      // Spend half the budget before answering, then never answer authenticate:
      // the handshake must give up at ~the original deadline, not a full
      // timeout after the initialize reply.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": initializeResult(
          authMethods: [
            {"id": "login", "name": "Login"},
          ],
        ),
      });
      await waitForFrame("authenticate");
      await expectLater(initializing, throwsA(isA<TimeoutException>()));
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(milliseconds: 850)),
        reason: "a fresh per-request timeout would let authenticate run until ~900 ms",
      );
    });

    test("new, load, and resume send the exact typed HTTP MCP wire value", () async {
      const server = AcpHttpMcpServer(
        name: "Sesori Device Canvas",
        url: "http://127.0.0.1:7777/mcp",
        headers: [AcpHttpHeader(name: "Authorization", value: "Bearer test-token")],
      );
      const expectedServer = {
        "type": "http",
        "name": "Sesori Device Canvas",
        "url": "http://127.0.0.1:7777/mcp",
        "headers": [
          {"name": "Authorization", "value": "Bearer test-token"},
        ],
      };

      final creating = api.newSession(
        cwd: "/new",
        timeout: const Duration(seconds: 5),
        mcpServers: const [server],
      );
      final newFrame = await waitForFrame("session/new");
      expect(newFrame["params"], {
        "cwd": "/new",
        "mcpServers": [expectedServer],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": newFrame["id"],
        "result": {"sessionId": "new-id"},
      });
      await creating;

      final loading = api.loadSession(
        sessionId: "load-id",
        cwd: "/load",
        timeout: const Duration(seconds: 5),
        mcpServers: const [server],
      );
      final loadFrame = await waitForFrame("session/load");
      expect(loadFrame["params"], {
        "sessionId": "load-id",
        "cwd": "/load",
        "mcpServers": [expectedServer],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": loadFrame["id"],
        "result": {"sessionId": "load-id"},
      });
      await loading;

      final resuming = api.resumeSession(
        sessionId: "resume-id",
        cwd: "/resume",
        timeout: const Duration(seconds: 5),
        mcpServers: const [server],
      );
      final resumeFrame = await waitForFrame("session/resume");
      expect(resumeFrame["params"], {
        "sessionId": "resume-id",
        "cwd": "/resume",
        "mcpServers": [expectedServer],
      });
      fake.emit({
        "jsonrpc": "2.0",
        "id": resumeFrame["id"],
        "result": {"sessionId": "resume-id"},
      });
      await resuming;
    });
  });
}
