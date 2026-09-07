import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("AcpOutputInterceptor preserves bytes across every split, including UTF-8, CRLF and EOF", () async {
    final bytes = utf8.encode("ordinary €\r\nprivate secret\nlast partial");
    for (var split = 0; split <= bytes.length; split++) {
      final lines = <String>[];
      final interceptor = AcpOutputInterceptor(
        maxLineBytes: 64,
        consumeLine: ({required line}) {
          final text = utf8.decode(line);
          lines.add(text);
          return text.startsWith("private ");
        },
      );
      final output = await interceptor
          .intercept(
            bytes: Stream.fromIterable([
              bytes.sublist(0, split),
              bytes.sublist(split),
            ]),
          )
          .expand((chunk) => chunk)
          .toList();
      expect(lines, ["ordinary €\r\n", "private secret\n", "last partial"]);
      expect(output, utf8.encode("ordinary €\r\nlast partial"));
    }
  });

  test("AcpOutputInterceptor bounds fragmented and complete lines before invoking callback", () async {
    for (final chunks in [
      [utf8.encode("secret")],
      [utf8.encode("sec"), utf8.encode("ret\n")],
    ]) {
      var called = false;
      final interceptor = AcpOutputInterceptor(
        maxLineBytes: 5,
        consumeLine: ({required line}) {
          called = true;
          return false;
        },
      );
      await expectLater(
        interceptor.intercept(bytes: Stream.fromIterable(chunks)).toList(),
        throwsA(
          isA<AcpOutputInterceptionException>().having((e) => e.toString(), "safe message", isNot(contains("secret"))),
        ),
      );
      expect(called, isFalse);
    }
  });

  test("AcpOutputInterceptor preserves a callback cause without exposing its text", () async {
    const cause = FormatException("private secret");
    final interceptor = AcpOutputInterceptor(maxLineBytes: 8, consumeLine: ({required line}) => throw cause);
    await expectLater(
      interceptor.intercept(bytes: Stream.value([10])).toList(),
      throwsA(
        isA<AcpOutputInterceptionException>()
            .having((e) => e.cause, "cause", same(cause))
            .having((e) => e.toString(), "safe message", isNot(contains("secret"))),
      ),
    );
  });

  test("AcpOutputInterceptor cancels an idle partial line without invoking the callback", () async {
    var cancelled = false;
    final input = StreamController<List<int>>(onCancel: () => cancelled = true);
    final interceptor = AcpOutputInterceptor(
      maxLineBytes: 64,
      consumeLine: ({required line}) {
        fail("A cancelled partial line must not be delivered");
      },
    );
    final subscription = interceptor.intercept(bytes: input.stream).listen((_) {});
    input.add(utf8.encode("partial private"));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(cancelled, isTrue);
    await input.close();
  });

  test("AcpOutputInterceptor limit includes terminator and state is per subscription", () async {
    final interceptor = AcpOutputInterceptor(maxLineBytes: 4, consumeLine: ({required line}) => false);
    for (var i = 0; i < 2; i++) {
      expect(await interceptor.intercept(bytes: Stream.value(utf8.encode("abc\n"))).toList(), [utf8.encode("abc\n")]);
    }
    expect(await interceptor.intercept(bytes: const Stream.empty()).toList(), isEmpty);
  });

  test("AcpStdioClient intercepts raw stdout/stderr before decoding and logging", () async {
    final logs = BufferingStdout();
    final previous = Log.level;
    Log.level = LogLevel.debug;
    addTearDown(() => Log.level = previous);
    await IOOverrides.runZoned(() async {
      final process = _RawProcess();
      final interceptor = AcpOutputInterceptor(maxLineBytes: 128, consumeLine: ({required line}) => line.first == 255);
      final client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "agent", args: [], includeParentEnvironment: true),
        processFactory: (_) async => process,
        stdoutInterceptor: interceptor,
        stderrInterceptor: interceptor,
      );
      await client.connect();
      final response = client.request(method: "initialize");
      process.out.add([255, ...utf8.encode("private-secret\n")]);
      process.err.add([255, ...utf8.encode("private-secret\n")]);
      process.err.add(utf8.encode("useful diagnostic\n"));
      process.out.add(utf8.encode('{"jsonrpc":"2.0","id":1,"result":true}\n'));
      expect(await response, isTrue);
      await process.err.close();
      await client.dispose();
      await process.out.close();
    }, stderr: () => logs);
    expect(logs.text, contains("useful diagnostic"));
    expect(logs.text, isNot(contains("private-secret")));
    expect(logs.text, isNot(contains("stream error")));
  });

  test("AcpStdioClient output overflow fails pending request with safe error and still disposes", () async {
    final process = _RawProcess();
    final client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(command: "agent", args: [], includeParentEnvironment: true),
      processFactory: (_) async => process,
      stdoutInterceptor: AcpOutputInterceptor(maxLineBytes: 4, consumeLine: ({required line}) => false),
    );
    await client.connect();
    final assertion = expectLater(client.request(method: "initialize"), throwsA(isA<AcpOutputInterceptionException>()));
    process.out.add(utf8.encode("oversize private secret"));
    await assertion;
    await client.dispose();
    expect(await process.exitCode, -15);
    await process.out.close();
    await process.err.close();
  });
}

class _RawProcess() implements AcpProcessHandle {
  final out = StreamController<List<int>>();
  final err = StreamController<List<int>>();
  final exited = Completer<int>();
  @override
  final IOSink stdin = CapturingIOSink();
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => err.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exited.isCompleted) exited.complete(-15);
    return true;
  }
}
