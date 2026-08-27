import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/runtime/bridge_cli_options.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime_runner.dart";
import "package:test/test.dart";

void main() {
  const validSecret = "0123456789abcdef0123456789abcdef";

  test("local TURN composition is absent by default", () {
    expect(buildDeviceCanvasLocalTurnCredentialBuilder(options: _options()), isNull);
  });

  test("loads one owner-only regular-file secret and builds credentials", () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp("sesori-turn-secret-test-");
    addTearDown(() => directory.delete(recursive: true));
    await _chmod("700", directory.path);
    final secret = File("${directory.path}/secret")..writeAsStringSync(validSecret);
    await _chmod("600", secret.path);

    final builder = buildDeviceCanvasLocalTurnCredentialBuilder(
      options: _options(
        urls: const ["turn:relay.example.test:3478?transport=udp"],
        secretFile: secret.path,
      ),
    );
    final configuration = builder!.build(
      operationId: "operation-1",
      leaseExpiresAt: 1700000600000,
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

    expect(configuration.username, "1700000300:operation-1");
    expect(configuration.credential, isNotEmpty);
    expect(configuration.toString(), isNot(contains(validSecret)));
  });

  test("rejects symlinks, permissive modes, and non-token contents without exposing the secret", () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp("sesori-turn-secret-reject-test-");
    addTearDown(() => directory.delete(recursive: true));
    await _chmod("700", directory.path);
    final secret = File("${directory.path}/secret")..writeAsStringSync(validSecret);
    await _chmod("600", secret.path);
    final link = Link("${directory.path}/secret-link")..createSync(secret.path);

    expect(() => readDeviceCanvasLocalTurnSecret(filePath: link.path), throwsFormatException);

    await _chmod("644", secret.path);
    expect(() => readDeviceCanvasLocalTurnSecret(filePath: secret.path), throwsFormatException);

    await _chmod("600", secret.path);
    secret.writeAsStringSync("x" * 31);
    expect(() => readDeviceCanvasLocalTurnSecret(filePath: secret.path), throwsFormatException);

    secret.writeAsBytesSync(utf8.encode("$validSecret\n"));
    Object? error;
    try {
      readDeviceCanvasLocalTurnSecret(filePath: secret.path);
    } on Object catch (caught) {
      error = caught;
    }
    expect(error, isA<FormatException>());
    expect(error.toString(), isNot(contains(validSecret)));

    secret.writeAsStringSync(validSecret);
    await _chmod("777", directory.path);
    expect(() => readDeviceCanvasLocalTurnSecret(filePath: secret.path), throwsFormatException);
    await _chmod("700", directory.path);
  });
}

BridgeCliOptions _options({List<String> urls = const <String>[], String? secretFile}) => BridgeCliOptions(
  cliArgs: const <String>[],
  relayUrl: "wss://relay.example.test",
  authBackendUrl: "https://api.example.test",
  dataDirectory: "/tmp/sesori-test",
  debugPort: null,
  logLevelName: "info",
  importPluginIds: const <String>[],
  deviceCanvasLocalTurnUrls: urls,
  deviceCanvasLocalTurnSecretFile: secretFile,
  controlUrl: null,
);

Future<void> _chmod(String mode, String filePath) async {
  final result = await Process.run("chmod", <String>[mode, filePath]);
  if (result.exitCode != 0) throw StateError("chmod failed");
}
