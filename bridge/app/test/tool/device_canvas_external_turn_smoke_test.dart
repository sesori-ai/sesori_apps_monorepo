import "dart:async";
import "dart:io";

import "package:args/args.dart";
import "package:test/test.dart";

import "../../tool/device_canvas_external_turn_smoke.dart";

void main() {
  test("parses canonical DNS transports without reading the shared secret", () {
    final options = parseDeviceCanvasExternalTurnSmokeOptions(
      _parser().parse(const [
        "--turn-url",
        "TURN:RELAY.EXAMPLE.TEST.:03478?TRANSPORT=UDP",
        "--turn-url",
        "turns:relay.example.test",
        "--secret-file",
        "relative-secret",
        "--ca-file",
        "relative-ca.pem",
      ]),
    );

    expect(options.urls, const [
      "turn:relay.example.test:3478?transport=udp",
      "turns:relay.example.test:5349?transport=tcp",
    ]);
    expect(options.secretFile, endsWith("relative-secret"));
    expect(options.caFile, endsWith("relative-ca.pem"));
    expect(options.openssl, "openssl");
  });

  test("requires DNS URLs, an owner secret path, and a CA bundle for TLS", () {
    for (final arguments in const <List<String>>[
      [],
      ["--turn-url", "turn:192.0.2.1", "--secret-file", "/tmp/secret"],
      ["--turn-url", "turn:relay.example.test"],
      ["--turn-url", "turns:relay.example.test", "--secret-file", "/tmp/secret"],
      [
        "--turn-url",
        "turn:relay.example.test",
        "--turn-url",
        "TURN:RELAY.EXAMPLE.TEST.:03478?TRANSPORT=UDP",
        "--secret-file",
        "/tmp/secret",
      ],
    ]) {
      expect(
        () => parseDeviceCanvasExternalTurnSmokeOptions(_parser().parse(arguments)),
        throwsFormatException,
        reason: arguments.toString(),
      );
    }
  });

  test("builds bounded UDP, TCP, and TLS uclient arguments without the static secret", () {
    const username = "1700000300:operation-1";
    const credential = "short-lived-credential";
    final udp = buildDeviceCanvasTurnutilsArguments(
      url: "turn:relay.example.test:3478?transport=udp",
      username: username,
      credential: credential,
    );
    final tcp = buildDeviceCanvasTurnutilsArguments(
      url: "turn:relay.example.test:3478?transport=tcp",
      username: username,
      credential: credential,
    );
    final tls = buildDeviceCanvasTurnutilsArguments(
      url: "turns:relay.example.test:5349?transport=tcp",
      username: username,
      credential: credential,
    );

    expect(udp, containsAllInOrder(["-y", "-c", "-n", "2", "-l", "100", "-u", username, "-w", credential]));
    expect(udp, isNot(contains("-t")));
    expect(tcp, contains("-t"));
    expect(tcp, isNot(contains("-S")));
    expect(tls, containsAllInOrder(["-t", "-S", "-u", username, "-w", credential]));
    expect(tls, isNot(contains("-E")));
    expect(tls.last, "relay.example.test");
  });

  test("builds a separate TLS chain, hostname, and SNI verification command", () {
    final arguments = buildDeviceCanvasOpensslArguments(
      url: "turns:relay.example.test:5349?transport=tcp",
      caFile: "/etc/ssl/cert.pem",
    );

    expect(arguments, containsAllInOrder(["-connect", "relay.example.test:5349"]));
    expect(arguments, containsAllInOrder(["-servername", "relay.example.test"]));
    expect(arguments, containsAllInOrder(["-verify_hostname", "relay.example.test"]));
    expect(arguments, contains("-verify_return_error"));
    expect(arguments, containsAllInOrder(["-CAfile", "/etc/ssl/cert.pem"]));
  });

  test("kills a smoke child that exceeds its deadline", () async {
    if (Platform.isWindows) return;

    await expectLater(
      runDeviceCanvasExternalTurnProcess(
        executable: "/bin/sleep",
        arguments: const ["5"],
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

ArgParser _parser() => ArgParser()
  ..addMultiOption("turn-url")
  ..addOption("secret-file")
  ..addOption("turnutils-uclient", defaultsTo: "turnutils_uclient")
  ..addOption("openssl", defaultsTo: "openssl")
  ..addOption("ca-file");
