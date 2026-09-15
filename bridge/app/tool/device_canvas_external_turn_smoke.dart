import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:args/args.dart";
import "package:path/path.dart" as path;
import "package:sesori_bridge/src/runtime/bridge_runtime_runner.dart" show readDeviceCanvasTurnSharedSecret;
import "package:sesori_bridge/src/services/device_canvas_turn_credential_builder.dart";
import "package:sesori_shared/sesori_shared.dart"
    show canonicalizeDeviceCanvasTurnUrl, isCanonicalDeviceCanvasDnsTurnUrl, maxDeviceCanvasTurnUrls;

class const DeviceCanvasExternalTurnSmokeOptions({
  required final List<String> urls,
  required final String secretFile,
  required final String turnutilsUclient,
  required final String openssl,
  required final String? caFile,
});

const Duration deviceCanvasExternalTurnSmokeProcessTimeout = Duration(seconds: 30);

Future<void> main(List<String> arguments) async {
  final parser = buildDeviceCanvasExternalTurnSmokeParser();
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

  final DeviceCanvasExternalTurnSmokeOptions options;
  try {
    options = parseDeviceCanvasExternalTurnSmokeOptions(results);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }

  try {
    for (final url in options.urls.where((url) => url.startsWith("turns:"))) {
      stdout.writeln("Verifying the TLS certificate chain and hostname for $url.");
      final tlsResult = await runDeviceCanvasExternalTurnProcess(
        executable: options.openssl,
        arguments: buildDeviceCanvasOpensslArguments(url: url, caFile: options.caFile!),
      );
      stdout.write(tlsResult.stdoutText);
      stderr.write(tlsResult.stderrText);
      if (tlsResult.exitCode != 0) {
        exitCode = tlsResult.exitCode;
        return;
      }
    }

    final sharedSecret = readDeviceCanvasTurnSharedSecret(filePath: options.secretFile);
    for (final url in options.urls) {
      final now = DateTime.now().toUtc();
      final configuration =
          DeviceCanvasTurnCredentialBuilder(
            urls: [url],
            sharedSecret: sharedSecret,
          ).build(
            operationId: _randomOperationId(),
            leaseExpiresAt: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
            now: now,
          );
      stdout.writeln("Testing $url with two 100-byte relayed messages.");
      final result = await runDeviceCanvasExternalTurnProcess(
        executable: options.turnutilsUclient,
        arguments: buildDeviceCanvasTurnutilsArguments(
          url: url,
          username: configuration.username,
          credential: configuration.credential,
        ),
      );
      stdout.write(result.stdoutText);
      stderr.write(result.stderrText);
      if (result.exitCode != 0) {
        exitCode = result.exitCode;
        return;
      }
    }
    stdout.writeln("External Device Canvas TURN smoke passed for ${options.urls.length} URL(s).");
  } on ProcessException catch (error) {
    stderr.writeln("Unable to start external TURN smoke process: ${error.message}");
    exitCode = 1;
  } on TimeoutException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln("Unable to read external TURN test input: ${error.message}");
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

ArgParser buildDeviceCanvasExternalTurnSmokeParser() => ArgParser()
  ..addFlag("help", abbr: "h", negatable: false)
  ..addMultiOption("turn-url", valueHelp: "url", help: "External DNS TURN URL. Repeatable.")
  ..addOption("secret-file", valueHelp: "path", help: "Owner-only coturn REST shared-secret file")
  ..addOption("turnutils-uclient", defaultsTo: "turnutils_uclient", valueHelp: "path")
  ..addOption("openssl", defaultsTo: "openssl", valueHelp: "path")
  ..addOption("ca-file", valueHelp: "path", help: "CA bundle required when testing a turns: URL");

DeviceCanvasExternalTurnSmokeOptions parseDeviceCanvasExternalTurnSmokeOptions(ArgResults results) {
  final rawUrls = List<String>.from(results["turn-url"] as List<String>);
  if (rawUrls.isEmpty || rawUrls.length > maxDeviceCanvasTurnUrls) {
    throw const FormatException("Supply between 1 and $maxDeviceCanvasTurnUrls --turn-url values.");
  }
  final urls = <String>[];
  for (final rawUrl in rawUrls) {
    final canonical = canonicalizeDeviceCanvasTurnUrl(rawUrl);
    if (canonical == null || !isCanonicalDeviceCanvasDnsTurnUrl(canonical)) {
      throw const FormatException("--turn-url must use a valid DNS TURN endpoint.");
    }
    if (urls.contains(canonical)) throw const FormatException("--turn-url values must be semantically distinct.");
    urls.add(canonical);
  }

  final secretFile = (results["secret-file"] as String?)?.trim();
  if (secretFile == null || secretFile.isEmpty) throw const FormatException("--secret-file is required.");
  final turnutilsUclient = (results["turnutils-uclient"] as String).trim();
  if (turnutilsUclient.isEmpty) throw const FormatException("--turnutils-uclient must not be empty.");
  final openssl = (results["openssl"] as String).trim();
  if (openssl.isEmpty) throw const FormatException("--openssl must not be empty.");
  final caFileValue = (results["ca-file"] as String?)?.trim();
  final caFile = caFileValue == null || caFileValue.isEmpty ? null : path.normalize(path.absolute(caFileValue));
  if (urls.any((url) => url.startsWith("turns:")) && caFile == null) {
    throw const FormatException("--ca-file is required when testing a turns: URL.");
  }

  return DeviceCanvasExternalTurnSmokeOptions(
    urls: List<String>.unmodifiable(urls),
    secretFile: path.normalize(path.absolute(secretFile)),
    turnutilsUclient: turnutilsUclient,
    openssl: openssl,
    caFile: caFile,
  );
}

List<String> buildDeviceCanvasOpensslArguments({required String url, required String caFile}) {
  final endpoint = _parseDeviceCanvasDnsTurnEndpoint(url);
  if (!endpoint.tls) throw ArgumentError.value(url, "url", "must use turns");
  return <String>[
    "s_client",
    "-connect",
    "${endpoint.host}:${endpoint.port}",
    "-servername",
    endpoint.host,
    "-verify_hostname",
    endpoint.host,
    "-verify_return_error",
    "-CAfile",
    caFile,
    "-brief",
    "-no_ign_eof",
  ];
}

List<String> buildDeviceCanvasTurnutilsArguments({
  required String url,
  required String username,
  required String credential,
}) {
  final endpoint = _parseDeviceCanvasDnsTurnEndpoint(url);

  return <String>[
    "-y",
    "-c",
    "-n",
    "2",
    "-l",
    "100",
    if (endpoint.transport == "tcp") "-t",
    if (endpoint.tls) "-S",
    "-u",
    username,
    "-w",
    credential,
    "-p",
    endpoint.port,
    endpoint.host,
  ];
}

Future<({int exitCode, String stdoutText, String stderrText})> runDeviceCanvasExternalTurnProcess({
  required String executable,
  required List<String> arguments,
  Duration timeout = deviceCanvasExternalTurnSmokeProcessTimeout,
}) async {
  if (timeout <= Duration.zero) throw ArgumentError.value(timeout, "timeout", "must be positive");
  final process = await Process.start(executable, arguments);
  final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
  final stderrFuture = process.stderr.transform(systemEncoding.decoder).join();
  await process.stdin.close();
  final exitCodeFuture = process.exitCode;
  try {
    final processExitCode = await exitCodeFuture.timeout(timeout);
    return (
      exitCode: processExitCode,
      stdoutText: await stdoutFuture,
      stderrText: await stderrFuture,
    );
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    try {
      await exitCodeFuture.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await exitCodeFuture;
    }
    await Future.wait([stdoutFuture, stderrFuture]);
    throw TimeoutException("$executable exceeded the ${timeout.inSeconds}-second external TURN smoke deadline");
  }
}

({String host, String port, String transport, bool tls}) _parseDeviceCanvasDnsTurnEndpoint(String url) {
  if (!isCanonicalDeviceCanvasDnsTurnUrl(url)) throw ArgumentError.value(url, "url", "must be canonical");
  final queryStart = url.indexOf("?");
  final rawEndpoint = url.substring(url.indexOf(":") + 1, queryStart);
  final portSeparator = rawEndpoint.lastIndexOf(":");
  return (
    host: rawEndpoint.substring(0, portSeparator),
    port: rawEndpoint.substring(portSeparator + 1),
    transport: url.substring(queryStart + "?transport=".length),
    tls: url.startsWith("turns:"),
  );
}

String _randomOperationId() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(18, (_) => random.nextInt(256))).replaceAll("=", "");
}
