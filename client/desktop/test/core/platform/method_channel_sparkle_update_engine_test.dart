import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/method_channel_sparkle_update_engine.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel("sesori/sparkle/test");

  test("drives the runner's Sparkle and relays downloads and restart requests", () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
    );
    final engine = MethodChannelSparkleUpdateEngine.forTesting(channel: channel);
    final List<SparkleDownloadedUpdate> downloads = <SparkleDownloadedUpdate>[];
    engine.downloadedUpdates.listen(downloads.add);
    int restartRequests = 0;
    engine.restartRequests.listen((_) => restartRequests++);

    await engine.start(
      feedUri: Uri.parse("https://updates.example/appcast.xml"),
      automaticChecks: false,
      showsBuildNumber: true,
    );
    await engine.setAutomaticChecks(enabled: true);
    await engine.checkNow();
    await engine.installAndRelaunch();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall("updateDownloaded", {"version": "1.8.5", "build": "1066"})),
      (_) {},
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall("restartRequested")),
      (_) {},
    );

    expect(calls.map((call) => call.method), <String>["start", "setAutomaticChecks", "checkNow", "installAndRelaunch"]);
    expect(calls.map((call) => call.arguments), <Object?>[
      <String, Object>{
        "feedUrl": "https://updates.example/appcast.xml",
        "automaticChecks": false,
        "showsBuildNumber": true,
      },
      <String, Object>{"enabled": true},
      null,
      null,
    ]);
    expect(downloads.map((update) => (update.version, update.buildNumber)), [("1.8.5", 1066)]);
    expect(restartRequests, 1);
  });
}
