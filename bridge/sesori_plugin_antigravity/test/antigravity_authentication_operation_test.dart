import "dart:async";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _target = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
const _pair = AntigravityRuntimePair(serverPath: "/runtime/agent", harnessPath: "/runtime/harness", target: _target);
const _selection = AntigravityRuntimeSelected(
  source: AntigravityRuntimeSource.explicit,
  pair: _pair,
  contract: AntigravityRuntimeContract(version: "synthetic", listsSessions: true, closesSessions: false),
);
final _authorization = AntigravityAuthorization(
  authorizationUri: Uri.parse("https://accounts.google.com/o/oauth2/v2/auth?state=synthetic"),
  callbackUri: Uri.parse("http://127.0.0.1:9876/"),
  state: "synthetic",
);
final _redirect = Uri.parse("http://127.0.0.1:9876/?state=synthetic&code=synthetic");

class _Profile() implements AntigravityProfileService {
  final prepared = AntigravityPreparedProfile(geminiHome: "/profile", environment: {"GEMINI_HOME": "/profile"});
  AntigravityAuthenticationBudget? budget;
  final started = Completer<void>();
  Completer<void>? gate;
  @override
  Future<AntigravityPreparedProfile> prepare({
    required AntigravityAuthenticationBudget budget,
    required Map<String, String> hostEnvironment,
  }) async {
    this.budget = budget;
    started.complete();
    await gate?.future;
    budget.remaining;
    return prepared;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime({required final _Profile profile}) implements AntigravityRuntimeService {
  AntigravityRuntimeResolution resolution = _selection;
  int calls = 0;
  @override
  Future<AntigravityRuntimeResolution> resolve({
    required String? explicitServerPath,
    required String? managedServerPath,
    required Map<String, String> pathEnvironment,
    required Map<String, String> probeEnvironment,
    required PlatformTarget target,
    required Duration timeout,
    required StartAbortSignal abortSignal,
  }) async {
    calls++;
    expect(explicitServerPath, "/runtime/agent");
    expect(managedServerPath, isNull);
    expect(pathEnvironment, same(profile.prepared.environment));
    expect(probeEnvironment, same(profile.prepared.environment));
    expect(abortSignal, same(profile.budget!.abortSignal));
    expect(timeout <= profile.budget!.timeout, isTrue);
    return resolution;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Authentication({required final _Profile profile}) implements AntigravityAuthenticationService {
  final updates = StreamController<AntigravityAuthorization>.broadcast(sync: true);
  final started = Completer<void>();
  final completed = Completer<void>();
  final callbackStarted = Completer<void>();
  Completer<void>? cleanupGate;
  Completer<void>? callbackGate;
  AntigravityAuthenticationException? callbackFailure;
  final redirects = <Uri>[];
  bool cleanedUp = false;
  bool disposed = false;
  @override
  Stream<AntigravityAuthorization> get authorizations => updates.stream;
  @override
  Future<void> authenticate({
    required AntigravityRuntimePair pair,
    required Map<String, String> environment,
    required AntigravityAuthenticationBudget budget,
  }) async {
    expect(pair, same(_pair));
    expect(environment, same(profile.prepared.environment));
    expect(budget, same(profile.budget));
    started.complete();
    try {
      await Future.any<void>([
        completed.future,
        budget.abortSignal.whenAborted.then<void>((_) => throw const PluginStartAbortedException()),
      ]).timeout(budget.remaining);
    } finally {
      await cleanupGate?.future;
      cleanedUp = true;
    }
  }

  @override
  Future<void> submitRedirect({
    required AntigravityAuthorization authorization,
    required Uri redirectUri,
    required AntigravityAuthenticationBudget budget,
  }) async {
    expect(authorization, same(_authorization));
    expect(budget, same(profile.budget));
    redirects.add(redirectUri);
    callbackStarted.complete();
    await callbackGate?.future;
    budget.remaining;
    if (callbackFailure case final failure?) throw failure;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await updates.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Attempt({final Duration timeout = const Duration(seconds: 2)}) {
  final profile = _Profile();
  late final runtime = _Runtime(profile: profile);
  late final authentication = _Authentication(profile: profile);
  final abort = StartAbortController();
  late final operation = AntigravityAuthenticationOperation(
    profile: profile,
    runtime: runtime,
    authentication: authentication,
    target: _target,
    explicitServerPath: "/runtime/agent",
    managedServerPath: null,
    hostEnvironment: {"GOOGLE_API_KEY": "synthetic"},
    aborted: abort.signal,
    timeout: timeout,
  ).operation;
  final events = <PluginAuthenticationBrowserEvent>[];
  final errors = <AsyncError>[];
  final done = Completer<void>();
  final challenge = Completer<PluginAuthenticationBrowserChallenge>();
  late final StreamSubscription<PluginAuthenticationBrowserEvent> subscription;

  void start() {
    subscription = operation.events.listen(
      (event) {
        events.add(event);
        if (event is PluginAuthenticationBrowserChallenge && !challenge.isCompleted) challenge.complete(event);
      },
      onError: (Object error, StackTrace stackTrace) => errors.add(AsyncError(error, stackTrace)),
      onDone: done.complete,
    );
  }

  Future<void> cancel() => subscription.cancel();

  Future<void> offer() async {
    await authentication.started.future;
    authentication.updates.add(_authorization);
    await challenge.future;
  }
}

void main() {
  test("prepares then probes then authenticates with one environment and budget; no challenge is required", () async {
    final attempt = _Attempt()..start();
    await attempt.authentication.started.future;
    attempt.authentication.completed.complete();
    await attempt.done.future;
    expect(attempt.events, [isA<PluginAuthenticationCompleted>()]);
    expect(attempt.errors, isEmpty);
    expect(attempt.runtime.calls, 1);
    expect(attempt.authentication.cleanedUp, isTrue);
    expect(attempt.authentication.disposed, isTrue);
  });

  test("one browser challenge supports same-host completion without dispatch", () async {
    final attempt = _Attempt()..start();
    await attempt.offer();
    expect((await attempt.challenge.future).authorizationUri, _authorization.authorizationUri);
    attempt.authentication.completed.complete();
    await attempt.done.future;
    expect(attempt.events, [isA<PluginAuthenticationBrowserChallenge>(), isA<PluginAuthenticationCompleted>()]);
    expect(attempt.authentication.redirects, isEmpty);
  });

  test("remote continuation is one-shot and completion waits for its in-flight transport", () async {
    final attempt = _Attempt();
    attempt.authentication.callbackGate = Completer<void>();
    attempt.start();
    await attempt.offer();
    final submitted = attempt.operation.submitRedirect(redirectUri: _redirect);
    await attempt.authentication.callbackStarted.future;
    await expectLater(
      attempt.operation.submitRedirect(redirectUri: _redirect),
      throwsA(isA<AntigravityAuthenticationException>()),
    );
    attempt.authentication.completed.complete();
    await Future<void>(() {});
    expect(attempt.done.isCompleted, isFalse);
    attempt.authentication.callbackGate!.complete();
    await submitted;
    await attempt.done.future;
    expect(attempt.authentication.redirects, [_redirect]);
    expect(attempt.errors, isEmpty);
    expect(attempt.events.last, isA<PluginAuthenticationCompleted>());
  });

  test("cancellation awaits callback and ACP cleanup; stale callbacks cannot affect the next attempt", () async {
    final attempt = _Attempt();
    attempt.authentication.cleanupGate = Completer<void>();
    attempt.authentication.callbackGate = Completer<void>();
    attempt.start();
    await attempt.offer();
    final submitted = expectLater(
      attempt.operation.submitRedirect(redirectUri: _redirect),
      throwsA(isA<PluginStartAbortedException>()),
    );
    await attempt.authentication.callbackStarted.future;
    attempt.abort.abort();
    await Future<void>(() {});
    expect(attempt.done.isCompleted, isFalse);
    attempt.authentication.cleanupGate!.complete();
    await Future<void>(() {});
    expect(attempt.done.isCompleted, isFalse);
    attempt.authentication.callbackGate!.complete();
    await submitted;
    await attempt.done.future;
    expect(attempt.errors.single.error, isA<PluginStartAbortedException>());
    final next = _Attempt()..start();
    await next.offer();
    await expectLater(
      attempt.operation.submitRedirect(redirectUri: _redirect),
      throwsA(isA<PluginStartAbortedException>()),
    );
    expect(next.authentication.redirects, isEmpty);
    next.authentication.completed.complete();
    await next.done.future;
  });

  test("stream cancellation aborts an idle authentication and waits for boundary cleanup", () async {
    final attempt = _Attempt();
    attempt.authentication.cleanupGate = Completer<void>();
    attempt.start();
    await attempt.offer();
    var cancelled = false;
    final cancelling = attempt.cancel().then((_) => cancelled = true);
    await Future<void>(() {});
    expect(cancelled, isFalse);
    attempt.authentication.cleanupGate!.complete();
    await cancelling;
    expect(attempt.authentication.cleanedUp, isTrue);
    expect(attempt.authentication.disposed, isTrue);
  });

  test("profile cancellation prevents probing and still disposes attempt peers", () async {
    final attempt = _Attempt();
    attempt.profile.gate = Completer<void>();
    attempt.start();
    await attempt.profile.started.future;
    attempt.abort.abort();
    attempt.profile.gate!.complete();
    await attempt.done.future;
    expect(attempt.runtime.calls, 0);
    expect(attempt.errors.single.error, isA<PluginStartAbortedException>());
    expect(attempt.authentication.disposed, isTrue);
  });

  test("runtime rejection prevents authentication and preserves typed resolution evidence", () async {
    final cases = [
      (
        resolution: const AntigravityRuntimeMissing(
          source: AntigravityRuntimeSource.explicit,
          component: AntigravityRuntimeComponent.harness,
        ),
        details: ["explicit", "missing harness"],
      ),
      (
        resolution: const AntigravityRuntimePairRejected(
          source: AntigravityRuntimeSource.path,
          component: AntigravityRuntimeComponent.server,
          issue: AntigravityRuntimePairIssue.wrongName,
        ),
        details: ["path", "server", "wrongName"],
      ),
      (
        resolution: AntigravityRuntimeContractRejected(
          source: AntigravityRuntimeSource.managed,
          pair: _pair,
          violations: [
            AntigravityRuntimeContractViolation.agentVersion,
            AntigravityRuntimeContractViolation.personalOauth,
          ],
        ),
        details: ["managed", _pair.serverPath, _pair.harnessPath, "agentVersion", "personalOauth"],
      ),
      (
        resolution: const AntigravityRuntimeUnsupported(target: _target),
        details: ["unsupported target", "macos/arm64"],
      ),
    ];
    for (final entry in cases) {
      final attempt = _Attempt();
      attempt.runtime.resolution = entry.resolution;
      attempt.start();
      await attempt.done.future;
      expect(attempt.authentication.started.isCompleted, isFalse);
      final failure = attempt.errors.single.error as AntigravityAuthenticationException;
      expect(failure.cause, same(entry.resolution));
      for (final detail in entry.details) {
        expect(failure.toString(), contains(detail));
      }
    }
  });

  test("deadline and process-exit failures settle after cleanup without terminal success", () async {
    for (final timeout in [false, true]) {
      final attempt = _Attempt(timeout: timeout ? const Duration(milliseconds: 30) : const Duration(seconds: 2))
        ..start();
      await attempt.authentication.started.future;
      const failure = AntigravityAuthenticationException(message: "ACP process exited", cause: null);
      final stack = StackTrace.fromString("synthetic process-exit stack");
      if (!timeout) attempt.authentication.completed.completeError(failure, stack);
      await attempt.done.future;
      expect(attempt.errors.single.error, timeout ? isA<TimeoutException>() : same(failure));
      if (!timeout) expect(attempt.errors.single.stackTrace, same(stack));
      expect(attempt.events, isEmpty);
      expect(attempt.authentication.cleanedUp, isTrue);
    }
  });

  test("malformed authorization and duplicate challenges fail closed and release authentication", () async {
    for (final malformed in [true, false]) {
      final attempt = _Attempt()..start();
      await attempt.authentication.started.future;
      if (malformed) {
        attempt.authentication.updates.addError(
          const AntigravityAuthenticationException(message: "Invalid authorization", cause: null),
        );
      } else {
        await attempt.offer();
        attempt.authentication.updates.add(_authorization);
      }
      await attempt.done.future;
      expect(attempt.errors.single.error, isA<AntigravityAuthenticationException>());
      expect(attempt.events.whereType<PluginAuthenticationCompleted>(), isEmpty);
      expect(attempt.authentication.cleanedUp, isTrue);
    }
  });

  test("service callback rejection retains the claim and fails the attempt with original error", () async {
    final attempt = _Attempt()..start();
    await attempt.offer();
    const failure = AntigravityAuthenticationException(message: "Invalid sign-in callback", cause: null);
    attempt.authentication.callbackFailure = failure;
    await expectLater(attempt.operation.submitRedirect(redirectUri: _redirect), throwsA(same(failure)));
    await attempt.done.future;
    expect(attempt.errors.single.error, same(failure));
    expect(attempt.authentication.redirects, hasLength(1));
    expect(attempt.events.whereType<PluginAuthenticationCompleted>(), isEmpty);
  });
}
