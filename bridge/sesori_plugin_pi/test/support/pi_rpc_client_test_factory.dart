import "dart:async";

import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";

/// Yields to the event loop so stream events queued by the fake are delivered.
Future<void> pump([int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

PiLaunchSpec testLaunchSpec() => PiLaunchSpec(
  binaryPath: "pi",
  workingDirectory: "/tmp/project",
  launch: PiNewSession(sessionId: "sesori-pi-1"),
  model: null,
  thinkingLevel: null,
  environment: const {},
);

/// A started client and its fake process.
typedef StartedClient = ({PiRpcClient client, FakePiProcess process});

/// Starts a client against a fake process. Pi has no handshake, so starting is
/// just spawning and wiring the pipes.
Future<StartedClient> startTestClient({
  FakePiProcess? process,
}) async {
  final fake = process ?? FakePiProcess();
  final client = PiRpcClient(
    launchSpec: testLaunchSpec(),
    processFactory: ({required spec}) async => fake,
  );
  await client.start();
  return (client: client, process: fake);
}

/// Waits for a command of [type] the client wrote to stdin, polling rather than
/// assuming a fixed number of microtasks.
///
/// Throws [StateError] on exhaustion so a missing command fails loudly instead
/// of timing the whole suite out.
Future<Map<String, Object?>> waitForCommand({
  required FakePiProcess process,
  required String type,
  int attempts = 50,
}) => waitForNthCommand(process: process, type: type, count: 1, attempts: attempts);

Future<Map<String, Object?>> waitForNthCommand({
  required FakePiProcess process,
  required String type,
  required int count,
  int attempts = 50,
}) async {
  for (var i = 0; i < attempts; i++) {
    final matches = process.written.where((frame) => frame["type"] == type).toList();
    if (matches.length >= count) return matches[count - 1];
    await pump();
  }
  throw StateError(
    "fewer than $count '$type' commands written after $attempts attempts; saw: "
    "${process.written.map((frame) => frame["type"]).toList()}",
  );
}
