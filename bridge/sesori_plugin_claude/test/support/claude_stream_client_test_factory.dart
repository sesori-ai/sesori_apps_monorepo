import "dart:async";
import "dart:convert";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";

/// Yields to the event loop so stream events queued by the fake are delivered.
Future<void> pump([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Waits for a frame of [type] the client wrote to stdin, polling rather than
/// assuming a fixed number of microtasks.
///
/// Throws [StateError] on exhaustion so a missing frame fails loudly instead of
/// timing the whole suite out.
Future<Map<String, Object?>> waitForFrame(
  FakeClaudeProcess fake,
  String type, {
  int attempts = 50,
}) async {
  for (var i = 0; i < attempts; i++) {
    for (final frame in fake.written) {
      if (frame["type"] == type) return frame;
    }
    await pump();
  }
  throw StateError(
    "no '$type' frame written after $attempts attempts; saw: "
    "${fake.written.map((frame) => frame["type"]).toList()}",
  );
}

/// A real UUID: `ClaudeSessionLaunch` rejects anything else, because the CLI
/// does.
const String testSessionId = "11111111-2222-4333-8444-555555555555";

/// A second valid id, for assertions that must show a value is carried through
/// rather than defaulted.
const String otherTestSessionId = "99999999-8888-4777-8666-555555555555";

ClaudeLaunchSpec testLaunchSpec({String sessionId = testSessionId}) {
  return ClaudeLaunchSpec(
    binaryPath: "claude",
    workingDirectory: "/tmp/project",
    launch: ClaudeNewSession(sessionId: sessionId),
    model: null,
    effort: null,
    permissionMode: null,
    allowedTools: const [],
  );
}

/// A connected client and its fake process.
typedef ConnectedClient = ({ClaudeStreamClient client, FakeClaudeProcess fake});

/// Connects a client against a fake, answering the `initialize` handshake that
/// [ClaudeStreamClient.connect] performs.
///
/// `connect()` cannot be awaited before the handshake is answered, so the
/// connect future is started, the request is awaited off the fake, and only
/// then is the response emitted.
Future<ConnectedClient> connectTestClient({
  FakeClaudeProcess? process,
  Map<String, Object?> handshake = const {},
  Duration controlTimeout = const Duration(seconds: 5),
  String sessionId = testSessionId,
}) async {
  final fake = process ?? FakeClaudeProcess();
  final client = ClaudeStreamClient(
    launchSpec: testLaunchSpec(sessionId: sessionId),
    processFactory: (_) async => fake,
    controlTimeout: controlTimeout,
  );

  final connected = client.connect();
  final request = await waitForFrame(fake, "control_request");
  fake.emitControlResponse(
    requestId: request["request_id"]! as String,
    payload: handshake,
  );
  await connected;
  return (client: client, fake: fake);
}

/// The `initialize` catalog shape, trimmed from a real capture with every
/// identifier replaced by a synthetic value.
Map<String, Object?> get sampleHandshake => {
  "commands": [
    {"name": "review", "description": "Review a pull request", "argumentHint": ""},
  ],
  "agents": [
    {"name": "general-purpose", "description": "General-purpose agent"},
  ],
  "models": [
    {
      "value": "default",
      "resolvedModel": "test-model-large",
      "displayName": "Default (recommended)",
      "description": "Best for everyday tasks",
      "supportsEffort": true,
      "supportedEffortLevels": ["low", "medium", "high", "xhigh", "max"],
    },
    {
      "value": "small",
      "resolvedModel": "test-model-small",
      "displayName": "Small",
      "description": "Fastest for quick answers",
    },
  ],
  "output_style": "default",
  "account": {"apiProvider": "firstParty", "subscriptionType": "max"},
};

/// A `system`/`init` frame, trimmed from a real capture.
Map<String, Object?> sampleInit({String sessionId = testSessionId}) => {
  "type": "system",
  "subtype": "init",
  "session_id": sessionId,
  "uuid": "init-uuid",
  "model": "test-model-large[1m]",
  "permissionMode": "auto",
  "capabilities": ["interrupt_receipt_v1", "interrupt_cancel_queued_v1"],
  "tools": ["Read", "Write"],
  "slash_commands": ["review"],
  "claude_code_version": "2.1.221",
  "cwd": "/tmp/project",
};

/// Encodes [frames] as one ndjson byte block, for framing tests.
List<int> ndjson(List<Map<String, Object?>> frames) => utf8.encode(frames.map(jsonEncode).join("\n"));
