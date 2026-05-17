import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/server/api/open_code_process_api.dart";
import "package:sesori_bridge/src/server/repositories/open_code_process_repository.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeProcessRepository", () {
    late _FakeOpenCodeProcessApi api;
    late OpenCodeProcessRepository repository;

    setUp(() {
      api = _FakeOpenCodeProcessApi();
      repository = OpenCodeProcessRepository(api: api);
    });

    test("OpenCode process repository wraps start and health probe", () async {
      final process = _FakeProcess(pidValue: 4123);
      final capturedAt = DateTime.utc(2026, 5, 15, 10, 0);
      final checkedAt = DateTime.utc(2026, 5, 15, 10, 1);
      api.startFact = OpenCodeStartFact(
        process: process,
        pid: 4123,
        startMarker: "Fri May 15 10:00:00 2026",
        executablePath: "/usr/local/bin/opencode",
        commandLine: "/usr/local/bin/opencode serve --port 43123 --hostname 127.0.0.1",
        ownerUser: "alex",
        platform: "macos",
        capturedAt: capturedAt,
        password: "secret",
      );
      api.probeFact = OpenCodeHealthProbeFact(
        uri: Uri.parse("http://127.0.0.1:43123/global/health"),
        statusCode: 200,
        error: null,
        checkedAt: checkedAt,
      );

      final startResult = await repository.startProcess(
        executablePath: "/usr/local/bin/opencode",
        port: 43123,
        password: "secret",
      );
      final probeResult = await repository.probeHealth(
        serverUri: Uri.parse("http://127.0.0.1:43123"),
        password: "secret",
      );

      expect(api.startExecutablePath, equals("/usr/local/bin/opencode"));
      expect(api.startPort, equals(43123));
      expect(api.startPassword, equals("secret"));
      expect(startResult.process, same(process));
      expect(startResult.password, equals("secret"));
      expect(startResult.identity.pid, equals(4123));
      expect(startResult.identity.startMarker, equals("Fri May 15 10:00:00 2026"));
      expect(startResult.identity.executablePath, equals("/usr/local/bin/opencode"));
      expect(startResult.identity.commandLine, contains("opencode serve"));
      expect(startResult.identity.ownerUser, equals("alex"));
      expect(startResult.identity.platform, equals("macos"));
      expect(startResult.identity.capturedAt, equals(capturedAt));

      expect(api.probeUri, equals(Uri.parse("http://127.0.0.1:43123")));
      expect(api.probePassword, equals("secret"));
      expect(probeResult.uri.toString(), equals("http://127.0.0.1:43123/global/health"));
      expect(probeResult.statusCode, equals(200));
      expect(probeResult.isHealthy, isTrue);
      expect(probeResult.error, isNull);
      expect(probeResult.checkedAt, equals(checkedAt));
    });
  });
}

class _FakeOpenCodeProcessApi implements OpenCodeProcessApi {
  late OpenCodeStartFact startFact;
  late OpenCodeHealthProbeFact probeFact;
  String? startExecutablePath;
  int? startPort;
  String? startPassword;
  Uri? probeUri;
  String? probePassword;

  @override
  String generatePassword() {
    return "generated-password";
  }

  @override
  Future<OpenCodeHealthProbeFact> probeHealth({required Uri serverUri, required String password}) async {
    probeUri = serverUri;
    probePassword = password;
    return probeFact;
  }

  @override
  Future<OpenCodeStartFact> start({
    required String executablePath,
    required int port,
    required String password,
  }) async {
    startExecutablePath = executablePath;
    startPort = port;
    startPassword = password;
    return startFact;
  }
}

class _FakeProcess implements Process {
  _FakeProcess({required int pidValue}) : _pidValue = pidValue;

  final int _pidValue;

  @override
  int get pid => _pidValue;

  @override
  Future<int> get exitCode async => 0;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => Stream<List<int>>.value(utf8.encode(""));

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(utf8.encode(""));

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return true;
  }
}
