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

  test("prefix gate preserves every split and EOF while classifying only matching lines", () async {
    final bytes = utf8.encode("short\nprivate secret\r\nordinary €\npri");
    for (var split = 0; split <= bytes.length; split++) {
      final consumed = <String>[];
      final gate = AcpOutputInterceptor(
        maxLineBytes: 32,
        prefix: AcpOutputPrefix(length: 8, matches: ({required prefix}) => utf8.decode(prefix) == "private "),
        consumeLine: ({required line}) {
          consumed.add(utf8.decode(line));
          return true;
        },
      );
      final output = await gate
          .intercept(
            bytes: Stream.fromIterable([
              bytes.sublist(0, split),
              bytes.sublist(split),
            ]),
          )
          .expand((chunk) => chunk)
          .toList();
      expect(output, utf8.encode("short\nordinary €\npri"));
      expect(consumed, ["private secret\r\n"]);
    }
  });

  test("nonmatching lines stream before newline without applying the private-line limit", () async {
    final input = StreamController<List<int>>();
    var received = 0;
    var classifications = 0;
    final gate = AcpOutputInterceptor(
      maxLineBytes: 16,
      prefix: AcpOutputPrefix(
        length: 2,
        matches: ({required prefix}) {
          classifications++;
          return false;
        },
      ),
      consumeLine: ({required line}) => throw StateError("nonmatching line must never be retained"),
    );
    final subscription = gate.intercept(bytes: input.stream).listen((chunk) => received += chunk.length);
    final chunk = List<int>.filled(65536, 65);
    // More than the supported individual image byte budget, without a newline.
    for (var i = 0; i < 400; i++) {
      input.add(chunk);
    }
    await Future<void>.delayed(Duration.zero);
    expect(received, 400 * chunk.length);
    expect(classifications, 1);
    await subscription.cancel();
    await input.close();
  });

  test("prefix matching lines still fail closed on overflow and wrap classifier errors", () async {
    for (final fails in [false, true]) {
      final cause = StateError("private secret");
      final gate = AcpOutputInterceptor(
        maxLineBytes: 8,
        prefix: AcpOutputPrefix(
          length: 2,
          matches: ({required prefix}) {
            if (fails) throw cause;
            return true;
          },
        ),
        consumeLine: ({required line}) => fail("oversized private line must not reach callback"),
      );
      await expectLater(
        gate
            .intercept(
              bytes: Stream.fromIterable([
                [65],
                List.filled(16, 65),
              ]),
            )
            .toList(),
        throwsA(
          isA<AcpOutputInterceptionException>()
              .having((e) => e.cause, "cause", fails ? same(cause) : isNull)
              .having((e) => e.toString(), "presentation", isNot(contains("secret"))),
        ),
      );
    }
  });

  test("prefix buffering and passthrough both forward cancellation immediately", () async {
    for (final prefixMatches in [true, false]) {
      var cancelled = false;
      final input = StreamController<List<int>>(onCancel: () => cancelled = true);
      final gate = AcpOutputInterceptor(
        maxLineBytes: 16,
        prefix: AcpOutputPrefix(length: 2, matches: ({required prefix}) => prefixMatches),
        consumeLine: ({required line}) => fail("cancelled line must never be delivered"),
      );
      final subscription = gate.intercept(bytes: input.stream).listen((_) {});
      input.add([65, 65, 65]);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(cancelled, isTrue);
      await input.close();
    }
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

  test("AcpStdioClient detaches after interception fails before a request and can reconnect", () async {
    for (final stderr in [false, true]) {
      for (final callbackFails in [false, true]) {
        final failed = _RawProcess();
        final replacement = _RawProcess();
        final processes = [failed, replacement];
        final interceptor = AcpOutputInterceptor(
          maxLineBytes: 64,
          consumeLine: ({required line}) {
            if (utf8.decode(line).startsWith("private")) throw const FormatException("private secret");
            return false;
          },
        );
        final client = AcpStdioClient(
          launchSpec: const AcpLaunchSpec(command: "agent", args: [], includeParentEnvironment: true),
          processFactory: (_) async => processes.removeAt(0),
          stdoutInterceptor: stderr ? null : interceptor,
          stderrInterceptor: stderr ? interceptor : null,
        );
        await client.connect();
        final exit = client.processExit;
        (stderr ? failed.err : failed.out).add(callbackFails ? utf8.encode("private secret\n") : List.filled(65, 112));
        await exit;
        expect(client.isConnected, isFalse);
        await expectLater(client.request(method: "initialize"), throwsStateError);
        await client.reset(gracefulTimeout: Duration.zero);
        await client.connect();
        final response = client.request(method: "initialize");
        replacement.out.add(utf8.encode('{"jsonrpc":"2.0","id":2,"result":true}\n'));
        expect(await response, isTrue);
        expect(client.isConnected, isTrue);
        await client.dispose();
        await failed.out.close();
        await failed.err.close();
        await replacement.out.close();
        await replacement.err.close();
      }
    }
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
