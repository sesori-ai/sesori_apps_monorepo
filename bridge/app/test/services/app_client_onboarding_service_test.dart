import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/repositories/app_client_status_repository.dart";
import "package:sesori_bridge/src/repositories/app_onboarding_state_repository.dart";
import "package:sesori_bridge/src/services/app_client_onboarding_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:test/test.dart";

void main() {
  group("AppClientOnboardingService", () {
    late _FakeAppClientStatusRepository statusRepository;
    late _FakeAppOnboardingStateRepository stateRepository;
    late AppClientOnboardingService service;
    late _CapturingStdout stdoutCapture;
    late _CapturingStdout stderrCapture;

    setUp(() {
      statusRepository = _FakeAppClientStatusRepository();
      stateRepository = _FakeAppOnboardingStateRepository();
      service = AppClientOnboardingService(
        statusRepository: statusRepository,
        stateRepository: stateRepository,
      );
      stdoutCapture = _CapturingStdout();
      stderrCapture = _CapturingStdout();
      Log.level = LogLevel.warning;
    });

    tearDown(() {
      Log.level = LogLevel.info;
    });

    test("matching marker skips without a request or output", () async {
      stateRepository.lookupResult = const AppOnboardingStatePresent();

      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: "user-a"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(statusRepository.accessTokens, isEmpty);
      expect(stateRepository.markCalls, equals(0));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, isEmpty);
    });

    test("missing JWT userId warns and skips all state and status work", () async {
      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: null),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(stateRepository.lookupCalls, equals(0));
      expect(statusRepository.accessTokens, isEmpty);
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });

    test("immediate registration marks the pair and skips silently", () async {
      statusRepository.results.add(const AppClientRegistered());
      final accessToken = _token(userId: "user-a");

      final decision = await _prepareCaptured(
        service: service,
        accessToken: accessToken,
        authBackendUrl: "https://auth.test/",
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(statusRepository.accessTokens, equals([accessToken]));
      expect(stateRepository.markCalls, equals(1));
      expect(stateRepository.lastAuthBackendUrl, equals("https://auth.test/"));
      expect(stateRepository.lastUserId, equals("user-a"));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, isEmpty);
    });

    test("confirmed absence returns prompt after exactly one silent status request", () async {
      statusRepository.results.add(const AppClientAbsent());
      final accessToken = _token(userId: "user-a");

      final decision = await _prepareCaptured(
        service: service,
        accessToken: accessToken,
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.prompt);
      expect(statusRepository.accessTokens, equals([accessToken]));
      expect(stateRepository.markCalls, equals(0));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, isEmpty);
    });

    test("marker read failure warns but confirmed registration still writes", () async {
      const readError = FileSystemException("cannot read marker");
      stateRepository.lookupResult = const AppOnboardingStateReadFailed(
        error: readError,
        stackTrace: StackTrace.empty,
      );
      statusRepository.results.add(const AppClientRegistered());

      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: "user-a"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(stateRepository.markCalls, equals(1));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });

    test("status failure warns and skips without retrying or marking", () async {
      statusRepository.results.add(
        const AppClientStatusUnavailable(error: FormatException("offline"), stackTrace: StackTrace.empty),
      );

      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: "user-a"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(statusRepository.accessTokens, hasLength(1));
      expect(stateRepository.markCalls, equals(0));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });

    test("unexpected preparation failure warns and skips", () async {
      statusRepository.error = StateError("unexpected status failure");

      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: "user-a"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(stateRepository.markCalls, equals(0));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });

    test("marker write failure remains observable and non-fatal", () async {
      stateRepository.markError = const FileSystemException("disk full");
      statusRepository.results.add(const AppClientRegistered());

      final decision = await _prepareCaptured(
        service: service,
        accessToken: _token(userId: "user-a"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(decision, AppClientOnboardingDecision.skip);
      expect(stateRepository.markCalls, equals(1));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });
  });
}

Future<AppClientOnboardingDecision> _prepareCaptured({
  required AppClientOnboardingService service,
  required String accessToken,
  String authBackendUrl = "https://auth.test",
  required _CapturingStdout out,
  required _CapturingStdout err,
}) {
  return IOOverrides.runZoned(
    () => service.prepare(accessToken: accessToken, authBackendUrl: authBackendUrl),
    stdout: () => out,
    stderr: () => err,
  );
}

String _token({required String? userId}) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({"userId": userId}))).replaceAll("=", "");
  return "header.$payload.signature";
}

class _FakeAppClientStatusRepository() implements AppClientStatusRepository {
  final List<AppClientStatusResult> results = [];
  final List<String> accessTokens = [];
  Object? error;

  @override
  Future<AppClientStatusResult> getStatus({required String accessToken}) async {
    accessTokens.add(accessToken);
    if (error != null) throw error!;
    return results.removeAt(0);
  }
}

class _FakeAppOnboardingStateRepository() implements AppOnboardingStateRepository {
  AppOnboardingStateLookup lookupResult = const AppOnboardingStateAbsent();
  int lookupCalls = 0;
  int markCalls = 0;
  Object? markError;
  String? lastAuthBackendUrl;
  String? lastUserId;

  @override
  Future<AppOnboardingStateLookup> lookup({required String authBackendUrl, required String userId}) async {
    lookupCalls += 1;
    return lookupResult;
  }

  @override
  Future<void> markCompleted({required String authBackendUrl, required String userId}) async {
    markCalls += 1;
    lastAuthBackendUrl = authBackendUrl;
    lastUserId = userId;
    if (markError != null) throw markError!;
  }

  @override
  Future<void> clearAll() {
    throw UnimplementedError("not used by onboarding service");
  }
}

class _CapturingStdout() implements Stdout {
  final List<String> lines = [];

  @override
  bool get supportsAnsiEscapes => false;

  @override
  void writeln([Object? object = ""]) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
