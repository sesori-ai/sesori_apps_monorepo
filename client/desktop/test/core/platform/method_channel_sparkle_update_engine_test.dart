import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/method_channel_sparkle_update_engine.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel("sesori/sparkle/test");

  test("drives the runner's Sparkle and relays downloaded versions", () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final engine = MethodChannelSparkleUpdateEngine.forTesting(channel: channel);
    final List<String> versions = <String>[];
    engine.downloadedVersions.listen(versions.add);

    await engine.start(feedUri: Uri.parse("https://updates.example/appcast.xml"), automaticChecks: false);
    await engine.setAutomaticChecks(enabled: true);
    await engine.checkNow();
    await engine.installAndRelaunch();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall("updateDownloaded", "1.8.5")),
      (_) {},
    );

    expect(calls.map((call) => call.method), <String>["start", "setAutomaticChecks", "checkNow", "installAndRelaunch"]);
    expect(calls.map((call) => call.arguments), <Object?>[
      <String, Object>{"feedUrl": "https://updates.example/appcast.xml", "automaticChecks": false},
      <String, Object>{"enabled": true},
      null,
      null,
    ]);
    expect(versions, <String>["1.8.5"]);
  });
}
