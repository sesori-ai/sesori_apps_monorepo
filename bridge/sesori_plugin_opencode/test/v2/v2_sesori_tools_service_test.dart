import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:opencode_plugin/src/open_code_raw_http_client.dart";
import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/api/sesori_bridge_mcp_api.dart";
import "package:opencode_plugin/src/v2/repositories/v2_sesori_tools_repository.dart";
import "package:opencode_plugin/src/v2/services/v2_sesori_tools_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _directory = "/fixture/project";
const _other = "/fixture/other";

void main() {
  late _Fixture fixture;
  late _RecordingAccess access;
  late V2SesoriToolsService service;

  V2SesoriToolsService build({Duration idleRelease = const Duration(hours: 1)}) => V2SesoriToolsService(
    repository: V2SesoriToolsRepository(
      api: OpenCodeV2Api(
        client: OpenCodeRawHttpClient(serverURL: fixture.url, password: "secret", client: http.Client()),
      ),
      bridge: SesoriBridgeMcpApi(client: http.Client()),
    ),
    access: access,
    idleRelease: idleRelease,
    retryDelay: const Duration(minutes: 1),
    attachWait: const Duration(seconds: 5),
  );

  setUp(() async {
    fixture = await _Fixture.start();
    access = _RecordingAccess(mcpUrl: "${fixture.url}/mcp");
    service = build();
  });
  tearDown(() async {
    await service.dispose();
    await fixture.close();
  });

  test("relays the folder's listing with one grant and each session's calls with its own", () async {
    await service.attach(directory: _directory);
    final socket = fixture.sockets.single;
    expect(socket.directory, _directory);
    expect(socket.name, sesoriMcpServerName);
    expect(socket.authorization, "Basic ${base64.encode(utf8.encode("opencode:secret"))}");
    // The listing happened before attach returned, with the folder's unbound grant.
    expect(fixture.bridgeTokens, ["token-1", "token-1"]);
    expect(access.bound, isEmpty);

    final first = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_a"),
    );
    final second = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_b"),
    );
    final again = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_a"),
    );

    expect(_text(first), "token-2 tools/call");
    expect(_text(second), "token-3 tools/call");
    expect(_text(again), "token-2 tools/call");
    expect(access.bound, {"token-2": "ses_a", "token-3": "ses_b"});
  });

  test("attributes a subagent's calls to its root session", () async {
    fixture.parents.addAll({"ses_grandchild": "ses_child", "ses_child": "ses_a"});
    await service.attach(directory: _directory);
    final socket = fixture.sockets.single;

    final child = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_grandchild"),
    );
    final root = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_a"),
    );

    expect(_text(child), "token-2 tools/call");
    expect(_text(root), "token-2 tools/call");
    expect(access.bound, {"token-2": "ses_a"});
  });

  test("refuses a call without a session and one made while agent tools are off", () async {
    await service.attach(directory: _directory);
    final socket = fixture.sockets.single;

    final unattributed = await socket.request(method: "tools/call", params: {"name": "list_tasks"});
    access.enabled = false;
    final off = await socket.request(
      method: "tools/call",
      params: _call(sessionId: "ses_a"),
    );

    expect(_text(unattributed), contains("only inside an OpenCode session"));
    expect(_text(off), contains("turned off"));
    expect(jsonDecode(off), containsPair("result", containsPair("isError", true)));
    expect(access.bound, isEmpty);
  });

  test("opens no socket while agent tools are off", () async {
    access.enabled = false;
    await service.attach(directory: _directory);
    expect(fixture.sockets, isEmpty);
  });

  test("links again after OpenCode closes a socket only once its event stream reconnects", () async {
    await service.attach(directory: _directory);
    await fixture.sockets.single.close();
    await fixture.sockets.single.closed;
    await pumpEventQueue();

    // Activity alone waits out the retry delay.
    service.touch(directory: _directory);
    await pumpEventQueue();
    expect(fixture.sockets, hasLength(1));

    service.reconnect(loaded: {_other});
    await fixture.attached(count: 3);
    expect([for (final socket in fixture.sockets) socket.directory], unorderedEquals([_directory, _directory, _other]));
  });

  test("lets a folder's socket go once its sessions stay idle", () async {
    await service.dispose();
    service = build(idleRelease: const Duration(milliseconds: 120));
    await service.attach(directory: _directory);
    await fixture.sockets.single.closed.timeout(const Duration(seconds: 5));
  });

  test("closes its sockets on dispose", () async {
    await service.attach(directory: _directory);
    await service.dispose();
    await fixture.sockets.single.closed.timeout(const Duration(seconds: 5));
  });
}

Map<String, Object?> _session({required String id, required String? parentId}) => {
  "id": id,
  "parentID": parentId,
  "projectID": "prj_fixture",
  "cost": 0,
  "tokens": {
    "input": 0,
    "output": 0,
    "reasoning": 0,
    "cache": {"read": 0, "write": 0},
  },
  "time": {"created": 0, "updated": 0},
  "location": {"directory": _directory},
};

Map<String, Object?> _call({required String sessionId}) => {
  "name": "list_tasks",
  "arguments": <String, Object?>{},
  "_meta": {"ai.opencode/sessionID": sessionId},
};

String _text(String reply) => switch (jsonDecode(reply)) {
  {"result": {"content": [{"text": final String text}]}} => text,
  final Object? other => throw StateError("Not a tool result: $other"),
};

/// Stands in for both OpenCode (the client-MCP WebSocket, acting as the MCP
/// client) and the bridge's MCP endpoint, which echoes the bearer token.
class _Fixture({required final HttpServer _server}) {
  final List<_OpenCodeSocket> sockets = [];
  final List<String?> bridgeTokens = [];

  /// Child session id to parent session id, as OpenCode reports them.
  final Map<String, String> parents = {};
  final StreamController<void> _attaches = StreamController<void>.broadcast();
  var _handshakes = 0;

  String get url => "http://127.0.0.1:${_server.port}";

  static Future<_Fixture> start() async {
    final fixture = _Fixture(server: await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    fixture._server.listen(fixture._handle);
    return fixture;
  }

  /// Waits until [count] sockets have finished OpenCode's attach handshake.
  Future<void> attached({required int count}) async {
    while (_handshakes < count) {
      await _attaches.stream.first.timeout(const Duration(seconds: 5));
    }
  }

  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.uri.path == "/api/experimental/client-mcp") {
      final socket = _OpenCodeSocket(
        socket: await WebSocketTransformer.upgrade(request),
        directory: request.uri.queryParameters["location[directory]"],
        name: request.uri.queryParameters["name"],
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
      );
      sockets.add(socket);
      await socket.handshake();
      _handshakes++;
      _attaches.add(null);
      return;
    }
    if (request.uri.path.startsWith("/api/session/")) {
      final id = request.uri.pathSegments.last;
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({"data": _session(id: id, parentId: parents[id])}));
      await request.response.close();
      return;
    }
    final token = request.headers.value(HttpHeaders.authorizationHeader)?.replaceFirst("Bearer ", "");
    bridgeTokens.add(token);
    final message = jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
    request.response
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          "jsonrpc": "2.0",
          "id": message["id"],
          "result": {
            "content": [
              {"type": "text", "text": "$token ${message["method"]}"},
            ],
          },
        }),
      );
    await request.response.close();
  }
}

/// OpenCode's side of one socket: it sends requests and reads replies.
class _OpenCodeSocket({
  required final WebSocket _socket,
  required final String? directory,
  required final String? name,
  required final String? authorization,
}) {
  final Map<int, Completer<String>> _pending = {};
  final Completer<void> _closed = Completer<void>();
  var _nextId = 0;

  this {
    _socket.listen(
      (frame) {
        final reply = jsonDecode(frame as String) as Map<String, dynamic>;
        _pending.remove(reply["id"])?.complete(frame);
      },
      onDone: _closed.complete,
    );
  }

  Future<void> get closed => _closed.future;

  /// What OpenCode does on attach: initialize, initialized, then list.
  Future<void> handshake() async {
    await request(method: "initialize", params: {"protocolVersion": "2025-11-25"});
    _socket.add(jsonEncode({"jsonrpc": "2.0", "method": "notifications/initialized"}));
    await request(method: "tools/list", params: null);
  }

  Future<String> request({required String method, required Map<String, Object?>? params}) {
    final id = _nextId++;
    final reply = _pending[id] = Completer<String>();
    _socket.add(jsonEncode({"jsonrpc": "2.0", "id": id, "method": method, "params": ?params}));
    return reply.future.timeout(const Duration(seconds: 5));
  }

  Future<void> close() => _socket.close();
}

class _RecordingAccess({required final String mcpUrl}) implements SesoriMcpAccess {
  bool enabled = true;
  final Map<String, String> bound = {};
  var _minted = 0;

  @override
  SesoriMcpLaunch? mint() {
    if (!enabled) return null;
    _minted++;
    return SesoriMcpLaunch(serverName: sesoriMcpServerName, url: mcpUrl, token: "token-$_minted");
  }

  @override
  void bind({required SesoriMcpLaunch launch, required String backendSessionId}) =>
      bound[launch.token] = backendSessionId;

  @override
  SesoriSkillBundle? get skillBundle => null;
}
