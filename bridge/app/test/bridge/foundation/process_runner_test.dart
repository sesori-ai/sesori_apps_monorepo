import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:test/test.dart";

void main() {
  test("waits for complete stdout and stderr before returning", () async {
    final directory = await Directory.systemTemp.createTemp("process_runner_test_");
    addTearDown(() => directory.delete(recursive: true));
    final script = File("${directory.path}/emit_output.dart");
    await script.writeAsString(r'''
import "dart:io";

void main() {
  for (var i = 0; i < 4096; i++) {
    stdout.writeln("stdout-$i");
    stderr.writeln("stderr-$i");
  }
}
''');

    final result = await ProcessRunner().run(
      Platform.resolvedExecutable,
      [script.path],
    );

    final expectedStdout = List<String>.generate(4096, (index) => "stdout-$index\n").join();
    final expectedStderr = List<String>.generate(4096, (index) => "stderr-$index\n").join();
    expect(result.exitCode, 0);
    expect(result.stdout, expectedStdout);
    expect(result.stderr, expectedStderr);
  });

  test("timeout includes output pipes retained by descendants", () async {
    final directory = await Directory.systemTemp.createTemp("process_runner_timeout_test_");
    addTearDown(() => directory.delete(recursive: true));
    final childScript = File("${directory.path}/child.dart");
    await childScript.writeAsString('''
import "dart:io";

Future<void> main(List<String> arguments) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, int.parse(arguments[0]));
  socket.writeln("child");
  await socket.flush();
  await socket.first;
  socket.writeln("cleaned");
  await socket.flush();
  await socket.close();
}
''');
    final parentScript = File("${directory.path}/parent.dart");
    await parentScript.writeAsString('''
import "dart:io";

Future<void> main(List<String> arguments) async {
  final child = await Process.start(
    Platform.resolvedExecutable,
    [arguments[0], arguments[1]],
    mode: ProcessStartMode.inheritStdio,
  );
  await File(arguments[2]).writeAsString(child.pid.toString());
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, int.parse(arguments[1]));
  socket.writeln("parent");
  await socket.flush();
  await socket.close();
}
''');

    final childPidFile = File("${directory.path}/child_pid");
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final connections = StreamIterator(server);
    Socket? childSocket;
    StreamIterator<String>? childMessages;
    int? childPid;
    addTearDown(() async {
      childSocket?.destroy();
      if (childPid case final pid?) Process.killPid(pid);
      await childMessages?.cancel();
      await connections.cancel();
    });
    final stopwatch = Stopwatch()..start();
    final run = ProcessRunner().run(
      Platform.resolvedExecutable,
      [parentScript.path, childScript.path, server.port.toString(), childPidFile.path],
      timeout: const Duration(seconds: 3),
    );
    final timeoutObserved = expectLater(run, throwsA(isA<TimeoutException>()));
    var childConnected = false;
    var parentConnected = false;
    for (var connectionCount = 0; connectionCount < 2; connectionCount++) {
      expect(
        await connections.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
        reason: "fixture should open both child and parent control connections",
      );
      final socket = connections.current;
      final messages = StreamIterator(
        socket.map<List<int>>((bytes) => bytes).transform(utf8.decoder).transform(const LineSplitter()),
      );
      expect(
        await messages.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
        reason: "fixture should identify its control connection",
      );
      if (messages.current == "child") {
        childSocket = socket;
        childMessages = messages;
        childConnected = true;
      } else {
        expect(messages.current, "parent");
        parentConnected = true;
        await messages.cancel();
      }
    }
    expect(childConnected, isTrue);
    expect(parentConnected, isTrue);
    childPid = int.parse(await childPidFile.readAsString());
    await timeoutObserved;
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 4)));
    expect(childPid, greaterThan(0));
    final connectedChildSocket = childSocket!;
    final connectedChildMessages = childMessages!;
    connectedChildSocket.write("terminate");
    await connectedChildSocket.flush();
    expect(
      await connectedChildMessages.moveNext().timeout(const Duration(seconds: 5)),
      isTrue,
      reason: "child should acknowledge cleanup",
    );
    expect(connectedChildMessages.current, "cleaned");
    await connectedChildSocket.close();
  });
}
