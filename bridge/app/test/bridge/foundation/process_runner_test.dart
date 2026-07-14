import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
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
Future<void> main() => Future<void>.delayed(const Duration(seconds: 3));
''');
    final parentScript = File("${directory.path}/parent.dart");
    await parentScript.writeAsString('''
import "dart:io";

Future<void> main(List<String> arguments) async {
  await Process.start(
    Platform.resolvedExecutable,
    [arguments.single],
    mode: ProcessStartMode.inheritStdio,
  );
}
''');

    final stopwatch = Stopwatch()..start();
    await expectLater(
      ProcessRunner().run(
        Platform.resolvedExecutable,
        [parentScript.path, childScript.path],
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    await Future<void>.delayed(const Duration(seconds: 3));
  });
}
