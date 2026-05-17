import "dart:convert";
import "dart:io";
import "dart:math";

import "package:http/http.dart" as http;

import "../foundation/server_clock.dart";

typedef OpenCodeProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool runInShell,
});

class OpenCodeProcessApi {
  OpenCodeProcessApi({
    required OpenCodeProcessStarter processStarter,
    required http.Client httpClient,
    required ServerClock clock,
    required Map<String, String> environment,
    required String? currentUser,
    required bool isWindows,
    required String platform,
  }) : _processStarter = processStarter,
       _httpClient = httpClient,
       _clock = clock,
       _environment = Map<String, String>.from(environment),
       _currentUser = currentUser,
       _isWindows = isWindows,
       _platform = platform;

  static const int passwordLength = 32;

  final OpenCodeProcessStarter _processStarter;
  final http.Client _httpClient;
  final ServerClock _clock;
  final Map<String, String> _environment;
  final String? _currentUser;
  final bool _isWindows;
  final String _platform;

  String generatePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(passwordLength, (_) => random.nextInt(256));
    return bytes.map((int byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  }

  Future<OpenCodeStartFact> start({
    required String executablePath,
    required int port,
    required String password,
  }) async {
    final arguments = <String>["serve", "--port", "$port", "--hostname", "127.0.0.1"];
    final environment = Map<String, String>.from(_environment);
    environment["OPENCODE_SERVER_PASSWORD"] = password;

    final process = await _processStarter(
      executablePath,
      arguments,
      environment: environment,
      runInShell: _isWindows,
    );
    process.stdout.drain<void>().ignore();
    process.stderr.drain<void>().ignore();

    return OpenCodeStartFact(
      process: process,
      pid: process.pid,
      startMarker: null,
      executablePath: executablePath,
      commandLine: [executablePath, ...arguments].join(" "),
      ownerUser: _currentUser,
      platform: _platform,
      capturedAt: _clock.now(),
      password: password,
    );
  }

  Future<OpenCodeHealthProbeFact> probeHealth({
    required Uri serverUri,
    required String password,
  }) async {
    final healthUri = serverUri.resolve("/global/health");
    final request = http.Request("GET", healthUri);
    request.headers["Authorization"] = "Basic ${base64Encode(utf8.encode("opencode:$password"))}";

    try {
      final response = await _httpClient.send(request);
      await response.stream.drain<void>();
      return OpenCodeHealthProbeFact(
        uri: healthUri,
        statusCode: response.statusCode,
        error: null,
        checkedAt: _clock.now(),
      );
    } catch (error) {
      return OpenCodeHealthProbeFact(
        uri: healthUri,
        statusCode: null,
        error: error,
        checkedAt: _clock.now(),
      );
    }
  }
}

class OpenCodeStartFact {
  const OpenCodeStartFact({
    required this.process,
    required this.pid,
    required this.startMarker,
    required this.executablePath,
    required this.commandLine,
    required this.ownerUser,
    required this.platform,
    required this.capturedAt,
    required this.password,
  });

  final Process process;
  final int pid;
  final String? startMarker;
  final String executablePath;
  final String commandLine;
  final String? ownerUser;
  final String platform;
  final DateTime capturedAt;
  final String password;
}

class OpenCodeHealthProbeFact {
  const OpenCodeHealthProbeFact({
    required this.uri,
    required this.statusCode,
    required this.error,
    required this.checkedAt,
  });

  final Uri uri;
  final int? statusCode;
  final Object? error;
  final DateTime checkedAt;
}
