import "dart:io";

import "../api/open_code_process_api.dart";
import "../foundation/process_identity.dart";

class OpenCodeProcessRepository {
  OpenCodeProcessRepository({required OpenCodeProcessApi api}) : _api = api;

  final OpenCodeProcessApi _api;

  String generatePassword() {
    return _api.generatePassword();
  }

  Future<OpenCodeStartResult> startProcess({
    required String executablePath,
    required int port,
    required String password,
  }) async {
    final fact = await _api.start(
      executablePath: executablePath,
      port: port,
      password: password,
    );

    return OpenCodeStartResult(
      process: fact.process,
      password: fact.password,
      identity: ProcessIdentity(
        pid: fact.pid,
        startMarker: fact.startMarker,
        executablePath: fact.executablePath,
        commandLine: fact.commandLine,
        ownerUser: fact.ownerUser,
        platform: fact.platform,
        capturedAt: fact.capturedAt,
      ),
    );
  }

  Future<OpenCodeHealthProbeResult> probeHealth({
    required Uri serverUri,
    required String password,
  }) async {
    final fact = await _api.probeHealth(serverUri: serverUri, password: password);
    return OpenCodeHealthProbeResult(
      uri: fact.uri,
      statusCode: fact.statusCode,
      isHealthy: fact.statusCode == 200,
      checkedAt: fact.checkedAt,
      error: fact.error,
    );
  }
}

class OpenCodeStartResult {
  const OpenCodeStartResult({
    required this.process,
    required this.password,
    required this.identity,
  });

  final Process process;
  final String password;
  final ProcessIdentity identity;
}

class OpenCodeHealthProbeResult {
  const OpenCodeHealthProbeResult({
    required this.uri,
    required this.statusCode,
    required this.isHealthy,
    required this.checkedAt,
    required this.error,
  });

  final Uri uri;
  final int? statusCode;
  final bool isHealthy;
  final DateTime checkedAt;
  final Object? error;
}
