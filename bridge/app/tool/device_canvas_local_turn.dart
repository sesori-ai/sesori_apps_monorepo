import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:args/args.dart";

class const DeviceCanvasLocalTurnOptions({
  required final String lanIp,
  required final String turnserver,
  required final int listeningPort,
  required final int minRelayPort,
  required final int maxRelayPort,
  required final String realm,
});

Future<void> main(List<String> arguments) async {
  final parser = _buildParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on ArgParserException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (results["help"] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final DeviceCanvasLocalTurnOptions options;
  try {
    options = parseDeviceCanvasLocalTurnOptions(results);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }

  final directory = await Directory.systemTemp.createTemp("sesori-device-canvas-turn-");
  Process? process;
  Future<void>? stopFuture;
  var stopRequested = false;
  StreamSubscription<ProcessSignal>? interruptSubscription;
  StreamSubscription<ProcessSignal>? terminateSubscription;
  StreamSubscription<ProcessSignal>? hangupSubscription;
  Future<void> requestStop() {
    stopRequested = true;
    final child = process;
    if (child == null) return Future<void>.value();
    return stopFuture ??= _stopCoturn(child);
  }

  try {
    interruptSubscription = ProcessSignal.sigint.watch().listen((_) => unawaited(requestStop()));
    terminateSubscription = ProcessSignal.sigterm.watch().listen((_) => unawaited(requestStop()));
    hangupSubscription = ProcessSignal.sighup.watch().listen((_) => unawaited(requestStop()));
    await _chmod("700", directory.path);
    final random = Random.secure();
    final secret = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll("=", "");
    final secretFile = File("${directory.path}/shared-secret")..writeAsStringSync(secret, flush: true);
    final configFile = File("${directory.path}/turnserver.conf")
      ..writeAsStringSync(
        buildDeviceCanvasCoturnConfig(options: options, secret: secret, pidFile: "${directory.path}/turnserver.pid"),
        flush: true,
      );
    await Future.wait([_chmod("600", secretFile.path), _chmod("600", configFile.path)]);

    stdout
      ..writeln("Starting local Device Canvas coturn on ${options.lanIp}:${options.listeningPort}.")
      ..writeln("Keep this process running, then append these secret-free flags to the Bridge run command:")
      ..writeln(buildDeviceCanvasBridgeFlags(options: options, secretFile: secretFile.path))
      ..writeln()
      ..writeln("Build the client with:")
      ..writeln("--dart-define=DEVICE_CANVAS_LAN_VIDEO=true --dart-define=DEVICE_CANVAS_LOCAL_TURN=true")
      ..writeln();

    if (stopRequested) return;
    process = await Process.start(
      options.turnserver,
      buildDeviceCanvasTurnserverArguments(configFile: configFile.path),
    );
    if (stopRequested) unawaited(requestStop());
    final stdoutDone = process.stdout.listen(stderr.add).asFuture<void>();
    final stderrDone = process.stderr.listen(stderr.add).asFuture<void>();
    final result = await process.exitCode;
    await stdoutDone;
    await stderrDone;
    if (result != 0) exitCode = result;
  } on ProcessException catch (error) {
    stderr.writeln("Failed to start coturn: ${error.message}");
    exitCode = 1;
  } finally {
    await interruptSubscription?.cancel();
    await terminateSubscription?.cancel();
    await hangupSubscription?.cancel();
    await requestStop();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

ArgParser _buildParser() => ArgParser()
  ..addFlag("help", abbr: "h", negatable: false)
  ..addOption("lan-ip", valueHelp: "private-ip", help: "Private or link-local LAN IPv4 advertised by coturn")
  ..addOption("turnserver", defaultsTo: "turnserver", valueHelp: "path")
  ..addOption("listening-port", defaultsTo: "3478", valueHelp: "port")
  ..addOption("min-relay-port", defaultsTo: "49160", valueHelp: "port")
  ..addOption("max-relay-port", defaultsTo: "49200", valueHelp: "port")
  ..addOption("realm", defaultsTo: "device-canvas.local", valueHelp: "realm");

DeviceCanvasLocalTurnOptions parseDeviceCanvasLocalTurnOptions(ArgResults results) {
  final lanIp = (results["lan-ip"] as String?)?.trim();
  if (lanIp == null || !_isPrivateLanIpv4(lanIp)) {
    throw const FormatException("--lan-ip must be a canonical private or link-local IPv4 address.");
  }
  final turnserver = (results["turnserver"] as String).trim();
  if (turnserver.isEmpty) throw const FormatException("--turnserver must not be empty.");
  final listeningPort = _parsePort(results["listening-port"] as String, name: "--listening-port");
  final minRelayPort = _parsePort(results["min-relay-port"] as String, name: "--min-relay-port");
  final maxRelayPort = _parsePort(results["max-relay-port"] as String, name: "--max-relay-port");
  if (minRelayPort >= maxRelayPort || maxRelayPort - minRelayPort < 16) {
    throw const FormatException("The relay port range must contain at least 17 ports.");
  }
  final realm = (results["realm"] as String).trim().toLowerCase();
  if (!RegExp(r"^[a-z0-9](?:[a-z0-9.-]{0,125}[a-z0-9])?$").hasMatch(realm)) {
    throw const FormatException("--realm must be an ASCII DNS-style value of at most 127 bytes.");
  }
  return DeviceCanvasLocalTurnOptions(
    lanIp: lanIp,
    turnserver: turnserver,
    listeningPort: listeningPort,
    minRelayPort: minRelayPort,
    maxRelayPort: maxRelayPort,
    realm: realm,
  );
}

String buildDeviceCanvasCoturnConfig({
  required DeviceCanvasLocalTurnOptions options,
  required String secret,
  required String pidFile,
}) =>
    """
listening-port=${options.listeningPort}
listening-ip=${options.lanIp}
relay-ip=${options.lanIp}
min-port=${options.minRelayPort}
max-port=${options.maxRelayPort}
realm=${options.realm}
fingerprint
use-auth-secret
static-auth-secret=$secret
stale-nonce=600
user-quota=4
total-quota=16
max-bps=10000000
bps-capacity=40000000
max-allocate-lifetime=300
denied-peer-ip=0.0.0.0-255.255.255.255
allowed-peer-ip=${options.lanIp}
no-tls
no-dtls
no-multicast-peers
pidfile=$pidFile
""";

List<String> buildDeviceCanvasTurnserverArguments({required String configFile}) => [
  "--simple-log",
  "--log-file=stdout",
  "--log-min-level=error",
  "-c",
  configFile,
];

String buildDeviceCanvasBridgeFlags({
  required DeviceCanvasLocalTurnOptions options,
  required String secretFile,
}) {
  final udpUrl = "turn:${options.lanIp}:${options.listeningPort}?transport=udp";
  final tcpUrl = "turn:${options.lanIp}:${options.listeningPort}?transport=tcp";
  return "--device-canvas-local-turn-url ${_shellQuote(udpUrl)} "
      "--device-canvas-local-turn-url ${_shellQuote(tcpUrl)} "
      "--device-canvas-local-turn-secret-file ${_shellQuote(secretFile)}";
}

bool _isPrivateLanIpv4(String value) {
  final fields = value.split(".");
  if (fields.length != 4) return false;
  final octets = <int>[];
  for (final field in fields) {
    if (field.isEmpty || field.length > 3 || !RegExp(r"^[0-9]+$").hasMatch(field)) return false;
    final octet = int.parse(field);
    if (octet > 255 || "$octet" != field) return false;
    octets.add(octet);
  }
  return octets[0] == 10 ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168) ||
      (octets[0] == 169 && octets[1] == 254);
}

int _parsePort(String value, {required String name}) {
  final port = int.tryParse(value);
  if (port == null || port < 1 || port > 65535) throw FormatException("$name must be between 1 and 65535.");
  return port;
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

Future<void> _chmod(String mode, String path) async {
  final result = await Process.run("chmod", [mode, path]);
  if (result.exitCode != 0) throw ProcessException("chmod", [mode, path], "Unable to restrict local TURN files");
}

Future<void> _stopCoturn(Process? process) async {
  if (process == null) return;
  process.kill(ProcessSignal.sigterm);
  try {
    await process.exitCode.timeout(const Duration(seconds: 3));
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
  }
}
