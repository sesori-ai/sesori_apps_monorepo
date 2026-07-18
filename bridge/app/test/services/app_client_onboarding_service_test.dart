import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/foundation/app_onboarding_formatter.dart";
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
    late _FakeTokenRefresher tokenRefresher;
    late _CapturingStdout stdoutCapture;
    late _CapturingStdout stderrCapture;

    setUp(() {
      statusRepository = _FakeAppClientStatusRepository();
      stateRepository = _FakeAppOnboardingStateRepository();
      tokenRefresher = _FakeTokenRefresher(accessToken: _token(userId: "user-a"));
      service = AppClientOnboardingService(
        statusRepository: statusRepository,
        stateRepository: stateRepository,
        formatter: _StubAppOnboardingFormatter(),
        tokenRefresher: tokenRefresher,
      );
      stdoutCapture = _CapturingStdout();
      stderrCapture = _CapturingStdout();
      Log.level = LogLevel.warning;
    });

    tearDown(() {
      Log.level = LogLevel.info;
    });

    test("matching marker performs no request and emits no output", () async {
      stateRepository.lookupResult = const AppOnboardingStatePresent();

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(statusRepository.waitValues, isEmpty);
      expect(stateRepository.markCalls, equals(0));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, isEmpty);
    });

    test("missing JWT userId warns and performs no marker or status request", () async {
      await _runCaptured(
        () => service.run(accessToken: _token(userId: null), authBackendUrl: "https://auth.test"),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(stateRepository.lookupCalls, equals(0));
      expect(statusRepository.waitValues, isEmpty);
      expect(stderrCapture.lines, hasLength(1));
    });

    test("immediate registration marks the pair and continues silently", () async {
      statusRepository.results.add(const AppClientRegistered());

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test/",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(statusRepository.waitValues, equals([false]));
      expect(stateRepository.markCalls, equals(1));
      expect(stateRepository.lastAuthBackendUrl, equals("https://auth.test/"));
      expect(stateRepository.lastUserId, equals("user-a"));
      expect(stdoutCapture.lines, isEmpty);
      expect(stderrCapture.lines, isEmpty);
    });

    test("confirmed absence shows guidance and polls until registration", () async {
      tokenRefresher.accessToken = "refreshed-token";
      statusRepository.results
        ..add(const AppClientAbsent())
        ..add(const AppClientAbsent())
        ..add(const AppClientAbsent())
        ..add(const AppClientRegistered());

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(statusRepository.waitValues, equals([false, true, true, true]));
      expect(statusRepository.accessTokens, [
        _token(userId: "user-a"),
        "refreshed-token",
        "refreshed-token",
        "refreshed-token",
      ]);
      expect(stateRepository.markCalls, equals(1));
      expect(stdoutCapture.lines, [
        "",
        "Connect the Sesori mobile app to continue",
        "",
        "Use the QR code or link below to install or open Sesori, then sign in with this same account.",
        "",
        AppOnboardingFormatter.appUrl,
        "",
        "Waiting for the Sesori mobile app to connect...",
        "Bridge startup is paused and will continue automatically once connected.",
        "",
        "Sesori mobile app connected. Continuing bridge startup.",
      ]);
    });

    test("wait failure keeps startup paused and retries", () {
      statusRepository.results
        ..add(const AppClientAbsent())
        ..add(
          const AppClientStatusUnavailable(
            error: FormatException("offline"),
            stackTrace: StackTrace.empty,
          ),
        )
        ..add(const AppClientRegistered());

      fakeAsync((async) {
        var completed = false;
        _runCaptured(
          () => service.run(
            accessToken: _token(userId: "user-a"),
            authBackendUrl: "https://auth.test",
          ),
          out: stdoutCapture,
          err: stderrCapture,
        ).then((_) => completed = true);

        async.flushMicrotasks();
        expect(statusRepository.waitValues, equals([false, true]));
        expect(completed, isFalse);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(statusRepository.waitValues, equals([false, true, true]));
        expect(completed, isTrue);
      });

      expect(stateRepository.markCalls, equals(1));
      expect(stderrCapture.lines, hasLength(1));
    });

    test("marker read failure warns but a confirmed status still attempts the write", () async {
      const readError = FileSystemException("cannot read marker");
      stateRepository.lookupResult = const AppOnboardingStateReadFailed(
        error: readError,
        stackTrace: StackTrace.empty,
      );
      statusRepository.results.add(const AppClientRegistered());

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(stateRepository.markCalls, equals(1));
      expect(stderrCapture.lines, hasLength(1));
    });

    test("remote failure warns once and does not retry or mark", () async {
      statusRepository.results.add(
        const AppClientStatusUnavailable(error: FormatException("offline"), stackTrace: StackTrace.empty),
      );

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(statusRepository.waitValues, equals([false]));
      expect(stateRepository.markCalls, equals(0));
      expect(stderrCapture.lines, hasLength(1));
    });

    test("marker write failure warns and startup continues", () async {
      stateRepository.markError = const FileSystemException("disk full");
      statusRepository.results.add(const AppClientRegistered());

      await _runCaptured(
        () => service.run(
          accessToken: _token(userId: "user-a"),
          authBackendUrl: "https://auth.test",
        ),
        out: stdoutCapture,
        err: stderrCapture,
      );

      expect(stateRepository.markCalls, equals(1));
      expect(stderrCapture.lines, hasLength(1));
    });
  });
}

Future<void> _runCaptured(
  Future<void> Function() operation, {
  required _CapturingStdout out,
  required _CapturingStdout err,
}) {
  return IOOverrides.runZoned(operation, stdout: () => out, stderr: () => err);
}

String _token({required String? userId}) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({"userId": userId}))).replaceAll("=", "");
  return "header.$payload.signature";
}

class _FakeAppClientStatusRepository implements AppClientStatusRepository {
  final List<AppClientStatusResult> results = [];
  final List<bool> waitValues = [];
  final List<String> accessTokens = [];

  @override
  Future<AppClientStatusResult> getStatus({required String accessToken, required bool wait}) async {
    accessTokens.add(accessToken);
    waitValues.add(wait);
    return results.removeAt(0);
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  _FakeTokenRefresher({required this.accessToken});

  String accessToken;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => accessToken;
}

class _FakeAppOnboardingStateRepository implements AppOnboardingStateRepository {
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

class _StubAppOnboardingFormatter implements AppOnboardingFormatter {
  @override
  String formatDestination() => AppOnboardingFormatter.appUrl;
}

class _CapturingStdout implements Stdout {
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
