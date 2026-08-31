import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/runtime/bridge_cli_options.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime_runner.dart";
import "package:test/test.dart";

void main() {
  const validSecret = "0123456789abcdef0123456789abcdef";

  test("development TURN composition is absent by default", () {
    expect(buildDeviceCanvasDevelopmentTurnCredentialBuilder(options: _options()), isNull);
  });

  test("loads one owner-only regular-file secret for local TURN", () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp("sesori-turn-secret-test-");
    addTearDown(() => directory.delete(recursive: true));
    await _chmod("700", directory.path);
    final secret = File("${directory.path}/secret")..writeAsStringSync(validSecret);
    await _chmod("600", secret.path);

    final builder = buildDeviceCanvasDevelopmentTurnCredentialBuilder(
      options: _options(
        localUrls: const ["turn:192.168.1.10:3478?transport=udp"],
        localSecretFile: secret.path,
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

  test("loads the same protected secret path for external TURN", () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp("sesori-external-turn-secret-test-");
    addTearDown(() => directory.delete(recursive: true));
    await _chmod("700", directory.path);
    final secret = File("${directory.path}/secret")..writeAsStringSync(validSecret);
    await _chmod("600", secret.path);

    final builder = buildDeviceCanvasDevelopmentTurnCredentialBuilder(
      options: _options(
        externalUrls: const ["turns:relay.example.test:5349?transport=tcp"],
        externalSecretFile: secret.path,
        externalEnabled: true,
      ),
    );
    final configuration = builder!.build(
      operationId: "operation-2",
      leaseExpiresAt: 1700000600000,
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

    expect(configuration.urls, const ["turns:relay.example.test:5349?transport=tcp"]);
    expect(configuration.username, "1700000300:operation-2");
    expect(configuration.toString(), isNot(contains(validSecret)));
  });

  test("rejects incomplete or overlapping development modes", () {
    expect(
      () => buildDeviceCanvasDevelopmentTurnCredentialBuilder(
        options: _options(
          externalUrls: const ["turn:relay.example.test:3478?transport=udp"],
          externalSecretFile: "/tmp/secret",
        ),
      ),
      throwsStateError,
    );
    expect(
      () => buildDeviceCanvasDevelopmentTurnCredentialBuilder(
        options: _options(
          localUrls: const ["turn:192.168.1.10:3478?transport=udp"],
          localSecretFile: "/tmp/local-secret",
          externalUrls: const ["turn:relay.example.test:3478?transport=udp"],
          externalSecretFile: "/tmp/external-secret",
          externalEnabled: true,
        ),
      ),
      throwsStateError,
    );
  });

  test("rejects symlinks, permissive modes, and non-token contents without exposing the secret", () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp("sesori-turn-secret-reject-test-");
    addTearDown(() => directory.delete(recursive: true));
    await _chmod("700", directory.path);
    final secret = File("${directory.path}/secret")..writeAsStringSync(validSecret);
    await _chmod("600", secret.path);
    final link = Link("${directory.path}/secret-link")..createSync(secret.path);

    expect(() => readDeviceCanvasTurnSharedSecret(filePath: link.path), throwsFormatException);

    await _chmod("644", secret.path);
    expect(() => readDeviceCanvasTurnSharedSecret(filePath: secret.path), throwsFormatException);

    await _chmod("600", secret.path);
    secret.writeAsStringSync("x" * 31);
    expect(() => readDeviceCanvasTurnSharedSecret(filePath: secret.path), throwsFormatException);

    secret.writeAsBytesSync(utf8.encode("$validSecret\n"));
    Object? error;
    try {
      readDeviceCanvasTurnSharedSecret(filePath: secret.path);
    } on Object catch (caught) {
      error = caught;
    }
    expect(error, isA<FormatException>());
    expect(error.toString(), isNot(contains(validSecret)));

    secret.writeAsStringSync(validSecret);
    await _chmod("755", directory.path);
    expect(() => readDeviceCanvasTurnSharedSecret(filePath: secret.path), throwsFormatException);

    await _chmod("777", directory.path);
    expect(() => readDeviceCanvasTurnSharedSecret(filePath: secret.path), throwsFormatException);
    await _chmod("700", directory.path);
  });
}

BridgeCliOptions _options({
  List<String> localUrls = const <String>[],
  String? localSecretFile,
  List<String> externalUrls = const <String>[],
  String? externalSecretFile,
  bool externalEnabled = false,
}) => BridgeCliOptions(
  cliArgs: const <String>[],
  relayUrl: "wss://relay.example.test",
  authBackendUrl: "https://api.example.test",
  dataDirectory: "/tmp/sesori-test",
  debugPort: null,
  logLevelName: "info",
  importPluginIds: const <String>[],
  deviceCanvasLocalTurnUrls: localUrls,
  deviceCanvasLocalTurnSecretFile: localSecretFile,
  deviceCanvasExternalTurnUrls: externalUrls,
  deviceCanvasExternalTurnSecretFile: externalSecretFile,
  deviceCanvasExternalTurnTestEnabled: externalEnabled,
  controlUrl: null,
);

Future<void> _chmod(String mode, String filePath) async {
  final result = await Process.run("chmod", <String>[mode, filePath]);
  if (result.exitCode != 0) throw StateError("chmod failed");
}
