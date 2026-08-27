import "package:args/args.dart";
import "package:test/test.dart";

import "../../tool/device_canvas_local_turn.dart";

void main() {
  test("parses a canonical private LAN address and bounded ports", () {
    final options = parseDeviceCanvasLocalTurnOptions(
      _parser().parse(const [
        "--lan-ip",
        "192.168.1.10",
        "--listening-port",
        "3479",
        "--min-relay-port",
        "50000",
        "--max-relay-port",
        "50020",
      ]),
    );

    expect(options.lanIp, "192.168.1.10");
    expect(options.listeningPort, 3479);
    expect(options.minRelayPort, 50000);
    expect(options.maxRelayPort, 50020);
  });

  test("rejects public, noncanonical, and undersized relay configurations", () {
    for (final arguments in const <List<String>>[
      ["--lan-ip", "8.8.8.8"],
      ["--lan-ip", "192.168.001.10"],
      ["--lan-ip", "192.168.1.10", "--min-relay-port", "50000", "--max-relay-port", "50001"],
    ]) {
      expect(() => parseDeviceCanvasLocalTurnOptions(_parser().parse(arguments)), throwsFormatException);
    }
    expect(
      () => parseDeviceCanvasLocalTurnOptions(
        _parser().parse(["--lan-ip", "192.168.1.10", "--realm", "a${"b" * 127}"]),
      ),
      throwsFormatException,
    );
  });

  test("accepts one-byte and 127-byte realms", () {
    for (final realm in ["a", "a${"b" * 126}"]) {
      final options = parseDeviceCanvasLocalTurnOptions(
        _parser().parse(["--lan-ip", "192.168.1.10", "--realm", realm]),
      );
      expect(options.realm, realm);
    }
  });

  test("coturn config and process arguments keep logs and the secret off disk and argv", () {
    const options = DeviceCanvasLocalTurnOptions(
      lanIp: "192.168.1.10",
      turnserver: "turnserver",
      listeningPort: 3478,
      minRelayPort: 49160,
      maxRelayPort: 49200,
      realm: "device-canvas.local",
    );
    const secret = "private-shared-secret";
    final config = buildDeviceCanvasCoturnConfig(
      options: options,
      secret: secret,
      pidFile: "/tmp/private/turnserver.pid",
    );
    final flags = buildDeviceCanvasBridgeFlags(options: options, secretFile: "/tmp/private/shared-secret");
    final arguments = buildDeviceCanvasTurnserverArguments(configFile: "/tmp/private/turnserver.conf");

    expect(config, contains("static-auth-secret=$secret"));
    expect(config, contains("no-tls"));
    expect(config, isNot(contains("no-loopback-peers")));
    expect(config, contains("min-port=49160"));
    expect(config, contains("max-allocate-lifetime=300"));
    expect(config, contains("denied-peer-ip=0.0.0.0-255.255.255.255"));
    expect(config, contains("allowed-peer-ip=192.168.1.10"));
    expect(arguments, containsAllInOrder(["--simple-log", "--log-file=stdout", "--log-min-level=error"]));
    expect(arguments, isNot(contains(secret)));
    expect(flags, contains("turn:192.168.1.10:3478?transport=udp"));
    expect(flags, contains("turn:192.168.1.10:3478?transport=tcp"));
    expect(flags, contains("/tmp/private/shared-secret"));
    expect(flags, isNot(contains(secret)));
  });
}

ArgParser _parser() => ArgParser()
  ..addOption("lan-ip")
  ..addOption("turnserver", defaultsTo: "turnserver")
  ..addOption("listening-port", defaultsTo: "3478")
  ..addOption("min-relay-port", defaultsTo: "49160")
  ..addOption("max-relay-port", defaultsTo: "49200")
  ..addOption("realm", defaultsTo: "device-canvas.local");
