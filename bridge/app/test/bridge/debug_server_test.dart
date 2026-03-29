import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/debug_server.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";

void main() {
  group("DebugServer SSE multi-client", () {
    late _FakeBridgePlugin plugin;
    late AppDatabase db;
    late DebugServer debugServer;

    setUp(() async {
      plugin = _FakeBridgePlugin();
      db = createTestDatabase();
      debugServer = DebugServer(
        plugin: plugin,
        projectsDao: db.projectsDao,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      await debugServer.start();
    });

    tearDown(() async {
      await debugServer.stop();
      await plugin.close();
      await db.close();
    });

    test("second SSE client receives events alongside first", () async {
      final first = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(first.close);

      final second = await _SseTestClient.connect(debugServer.boundPort!);
      addTearDown(second.close);

      plugin.add(const BridgeSseServerConnected());

      final firstEvent = await first.nextEvent();
      final secondEvent = await second.nextEvent();

      expect(firstEvent, contains("server.connected"));
      expect(secondEvent, contains("server.connected"));
    });

    test(
      "first client still receives events after second disconnects",
      () async {
        final first = await _SseTestClient.connect(debugServer.boundPort!);
        addTearDown(first.close);

        final second = await _SseTestClient.connect(debugServer.boundPort!);

        await second.close();

        plugin.add(const BridgeSseServerConnected());
        final firstEvent = await first.nextEvent();
        expect(firstEvent, contains("server.connected"));
      },
    );

    test("plugin subscription is released when last client disconnects", () async {
      final trackingPlugin = _TrackingBridgePlugin();
      final trackingDb = createTestDatabase();
      final trackingServer = DebugServer(
        plugin: trackingPlugin,
        projectsDao: trackingDb.projectsDao,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      await trackingServer.start();
      addTearDown(trackingServer.stop);
      addTearDown(trackingPlugin.close);
      addTearDown(trackingDb.close);

      final first = await _SseTestClient.connect(trackingServer.boundPort!);
      final second = await _SseTestClient.connect(trackingServer.boundPort!);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(trackingPlugin.subscribeCount, equals(1));

      await second.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(trackingPlugin.unsubscribeCount, equals(0));

      await first.close();
      await trackingServer.stop();
      expect(trackingPlugin.unsubscribeCount, equals(1));
    });
  });

  group("DebugServer HTTP requests", () {
    late _FakeBridgePlugin plugin;
    late AppDatabase db;
    late DebugServer debugServer;

    setUp(() async {
      plugin = _FakeBridgePlugin();
      db = createTestDatabase();
      debugServer = DebugServer(
        plugin: plugin,
        projectsDao: db.projectsDao,
        port: 0,
        failureReporter: FakeFailureReporter(),
      );
      await debugServer.start();
    });

    tearDown(() async {
      await debugServer.stop();
      await plugin.close();
      await db.close();
    });

    test("GET /project returns project list as JSON", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", name: "My Project"),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/project"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as List<dynamic>;
      expect(decoded.length, equals(1));
      final project = decoded[0] as Map<String, dynamic>;
      expect(project["id"], equals("p1"));
      expect(project["name"], equals("My Project"));
    });

    test("GET /session without directory header returns 400", () async {
      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/session"),
      );
      final response = await request.close();
      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test("GET /session with directory header returns session list", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp/test",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/session"),
      );
      request.headers.set("x-project-id", "/tmp/test");
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as List<dynamic>;
      expect(decoded.length, equals(1));
      final session = decoded[0] as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
    });

    test("GET /session/{id}/message returns messages", () async {
      plugin.messagesResult = [
        const PluginMessageWithParts(
          info: PluginMessage(
            role: "user",
            id: "m1",
            sessionID: "s1",
            agent: null,
            modelID: null,
            providerID: null,
          ),
          parts: [],
        ),
      ];

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse(
          "http://127.0.0.1:${debugServer.boundPort!}/session/s1/message",
        ),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.ok));
      final decoded = jsonDecode(body) as List<dynamic>;
      expect(decoded.length, equals(1));
    });

    test("returns 502 on plugin error", () async {
      plugin.throwOnGetProjects = true;

      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.getUrl(
        Uri.parse("http://127.0.0.1:${debugServer.boundPort!}/project"),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      expect(response.statusCode, equals(HttpStatus.badGateway));
      expect(body, contains("request failed"));
    });
  });
}

// ---------------------------------------------------------------------------
// Fake plugin implementations
// ---------------------------------------------------------------------------

class _FakeBridgePlugin implements BridgePlugin {
  final _controller = StreamController<BridgeSseEvent>.broadcast();

  List<PluginProject> projectsResult = [];
  List<PluginSession> sessionsResult = [];
  List<PluginMessageWithParts> messagesResult = [];
  bool throwOnGetProjects = false;

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  @override
  Future<List<PluginProject>> getProjects() async {
    if (throwOnGetProjects) throw Exception("fake error");
    return projectsResult;
  }

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => sessionsResult;

  @override
  Future<PluginSession> createSession({
    required String directory,
    String? parentSessionId,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginSession> updateSessionArchiveStatus(
    String sessionId, {
    required bool archived,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async =>
      const PluginProject(id: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => messagesResult;

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents() async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "");

  @override
  Future<String> healthCheck() async => '{"healthy":true}';

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async =>
      const PluginProvidersResult(providers: []);

  @override
  Future<void> dispose() async {}

  void add(BridgeSseEvent event) => _controller.add(event);
  Future<void> close() => _controller.close();
}

/// Plugin that tracks subscribe/unsubscribe counts via a wrapping stream.
class _TrackingBridgePlugin implements BridgePlugin {
  final _eventController = StreamController<BridgeSseEvent>.broadcast();
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  @override
  String get id => "tracking";

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      subscribeCount++;
      final sub = _eventController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () {
        unsubscribeCount++;
        sub.cancel();
      };
    });
  }

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    String? parentSessionId,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginSession> updateSessionArchiveStatus(
    String sessionId, {
    required bool archived,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    summary: null,
  );

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async =>
      const PluginProject(id: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => [];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents() async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "");

  @override
  Future<String> healthCheck() async => '{"healthy":true}';

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async =>
      const PluginProvidersResult(providers: []);

  @override
  Future<void> dispose() async {}

  Future<void> close() => _eventController.close();
}

// ---------------------------------------------------------------------------
// SSE test client
// ---------------------------------------------------------------------------

class _SseTestClient {
  final Socket _socket;
  final StreamIterator<String> _lines;

  _SseTestClient._(this._socket, this._lines);

  static Future<_SseTestClient> connect(int port) async {
    final socket = await Socket.connect("127.0.0.1", port);
    socket.write(
      "GET /global/event HTTP/1.0\r\n"
      "Host: 127.0.0.1\r\n"
      "Accept: text/event-stream\r\n"
      "\r\n",
    );

    final lineController = StreamController<String>();
    final lines = StreamIterator(lineController.stream);

    var buffer = "";
    var headersParsed = false;
    var lineBuffer = "";

    socket.listen(
      (chunk) {
        buffer += utf8.decode(chunk);

        if (!headersParsed) {
          final headerEnd = buffer.indexOf("\r\n\r\n");
          if (headerEnd == -1) {
            return;
          }
          headersParsed = true;
          buffer = buffer.substring(headerEnd + 4);
        }

        lineBuffer += buffer;
        buffer = "";

        final parts = lineBuffer.split("\n");
        lineBuffer = parts.removeLast();
        for (final part in parts) {
          final line = part.endsWith("\r") ? part.substring(0, part.length - 1) : part;
          lineController.add(line);
        }
      },
      onDone: () {
        if (!lineController.isClosed) {
          lineController.close();
        }
      },
      onError: (_) {
        if (!lineController.isClosed) {
          lineController.close();
        }
      },
      cancelOnError: true,
    );

    final instance = _SseTestClient._(socket, lines);
    await instance._waitForReady();
    return instance;
  }

  Future<String> nextEvent() async {
    while (await _lines.moveNext()) {
      final line = _lines.current;
      if (line.startsWith("data: ")) {
        return line.substring(6);
      }
    }
    throw StateError("SSE stream ended before event arrived");
  }

  Future<void> close() async {
    await _socket.close();
    await _lines.cancel();
  }

  Future<void> _waitForReady() async {
    while (await _lines.moveNext()) {
      if (_lines.current == ": ok") {
        return;
      }
    }
    throw StateError("SSE stream ended before ready marker");
  }
}
