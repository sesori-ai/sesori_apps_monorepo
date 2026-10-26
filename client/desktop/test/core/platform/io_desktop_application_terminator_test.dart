import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/io_desktop_application_terminator.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel("sesori/termination/test");
  late List<String> calls;
  late int exits;

  IoDesktopApplicationTerminator terminator({required bool isMacOS}) => IoDesktopApplicationTerminator.forTesting(
    isMacOS: isMacOS,
    channel: channel,
    exit: () => exits++,
  );

  void answerRunner({required Object? Function(MethodCall call) answer}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return answer(call);
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
  }

  setUp(() {
    calls = <String>[];
    exits = 0;
  });

  test("exits the process directly off macOS", () async {
    answerRunner(answer: (_) => null);

    terminator(isMacOS: false)
      ..terminate()
      ..cancelTermination();
    await pumpEventQueue();

    expect(exits, 1);
    expect(calls, isEmpty);
  });

  test("macOS terminates and declines through the runner", () async {
    answerRunner(answer: (_) => null);

    terminator(isMacOS: true)
      ..cancelTermination()
      ..terminate();
    await pumpEventQueue();

    expect(calls, <String>["cancelTermination", "terminate"]);
    expect(exits, 0);
  });

  test("macOS exits directly when the runner cannot terminate", () async {
    answerRunner(answer: (_) => throw PlatformException(code: "unavailable"));

    terminator(isMacOS: true).terminate();
    await pumpEventQueue();

    expect(exits, 1);
  });
}
