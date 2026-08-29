import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/macos_legacy_keychain_client.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel("test/legacy-keychain");
  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        calls.add(call);
        return call.method == "read" ? "stored-value" : null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  test("translates typed storage operations to the native channel", () async {
    final MacOsLegacyKeychainClient client = MacOsLegacyKeychainClient.forTesting(channel: channel);

    expect(await client.read(key: "access_token"), "stored-value");
    await client.write(key: "refresh_token", value: "secret");
    await client.delete(key: "pkce_verifier");

    expect(calls.map((MethodCall call) => call.method), <String>["read", "write", "delete"]);
    expect(calls[0].arguments, <String, String>{"key": "access_token"});
    expect(calls[1].arguments, <String, String>{"key": "refresh_token", "value": "secret"});
    expect(calls[2].arguments, <String, String>{"key": "pkce_verifier"});
  });
}
