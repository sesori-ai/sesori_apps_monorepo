import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/listeners/viewed_project_pr_refresh_listener.dart";
import "package:sesori_bridge/src/services/pr_sync_service.dart";
import "package:sesori_bridge/src/services/project_view_tracker.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, LogLevel;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ViewedProjectPrRefreshListener", () {
    test("is passive until start and immediately refreshes existing active projects", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");

        async.elapse(const Duration(minutes: 1));
        expect(harness.service.calls, isEmpty);

        harness.listener.start();
        harness.listener.start();

        expect(harness.service.calls, hasLength(1));
        expect(harness.service.calls.single.projectIds, {"project-x"});
        expect(harness.service.calls.single.refreshPolicy, PrRefreshPolicy.viewedProject);
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("starts the interval only after the admitted refresh completes", () {
      fakeAsync((async) {
        final harness = _Harness()..service.completeImmediately = false;
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");

        async.elapse(const Duration(minutes: 1));
        expect(harness.service.calls, hasLength(1));

        harness.service.complete(callIndex: 0);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 29));
        expect(harness.service.calls, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(2));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("timer refreshes the full active project union", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        harness.tracker.setViewing(connID: 2, projectId: "project-y");
        async.flushMicrotasks();

        expect(harness.service.calls, hasLength(2));
        async.elapse(const Duration(seconds: 30));

        expect(harness.service.calls, hasLength(3));
        expect(harness.service.calls.last.projectIds, {"project-x", "project-y"});
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("submits a newly added project while prior work is in flight", () {
      fakeAsync((async) {
        final harness = _Harness()..service.completeImmediately = false;
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        harness.tracker.setViewing(connID: 2, projectId: "project-y");

        expect(harness.service.calls, hasLength(2));
        expect(harness.service.calls[0].projectIds, {"project-x"});
        expect(harness.service.calls[1].projectIds, {"project-y"});

        harness.service.complete(callIndex: 0);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        expect(harness.service.calls, hasLength(2), reason: "an older completion must not arm the timer");

        harness.service.complete(callIndex: 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        expect(harness.service.calls, hasLength(3));
        expect(harness.service.calls.last.projectIds, {"project-x", "project-y"});
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("a new activation cancels and restarts a pending completion-based timer", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));

        harness.tracker.setViewing(connID: 2, projectId: "project-y");
        async.flushMicrotasks();
        expect(harness.service.calls, hasLength(2));

        async.elapse(const Duration(seconds: 29));
        expect(harness.service.calls, hasLength(2));
        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(3));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("a committed interval change cancels and rearms the pending timer", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        harness.settingsService.setInterval(intervalSeconds: 15);
        async.elapse(const Duration(seconds: 14));
        expect(harness.service.calls, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(2));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("an interval change during refresh applies when completion arms the timer", () {
      fakeAsync((async) {
        final harness = _Harness()..service.completeImmediately = false;
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");

        harness.settingsService.setInterval(intervalSeconds: 15);
        async.elapse(const Duration(minutes: 1));
        expect(harness.service.calls, hasLength(1));

        harness.service.complete(callIndex: 0);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 14));
        expect(harness.service.calls, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(2));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("duplicate viewers neither refresh nor disturb the pending timer", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        harness.tracker.setViewing(connID: 2, projectId: "project-x");
        expect(harness.service.calls, hasLength(1));

        async.elapse(const Duration(seconds: 20));
        expect(harness.service.calls, hasLength(2));
        expect(harness.service.calls.last.projectIds, {"project-x"});
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("removal-only changes preserve scheduling while the union is nonempty", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        harness.tracker.setViewing(connID: 2, projectId: "project-y");
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        harness.tracker.releaseConnection(connID: 1);
        async.elapse(const Duration(seconds: 19));
        expect(harness.service.calls, hasLength(2));

        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(3));
        expect(harness.service.calls.last.projectIds, {"project-y"});
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("final clear cancels timers and suppresses in-flight completion rearm", () {
      fakeAsync((async) {
        final harness = _Harness()..service.completeImmediately = false;
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        harness.tracker.clearAll();

        harness.service.complete(callIndex: 0);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));

        expect(harness.service.calls, hasLength(1));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("final clear cancels an already armed timer", () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.listener.start();
        harness.tracker.setViewing(connID: 1, projectId: "project-x");
        async.flushMicrotasks();
        harness.tracker.clearAll();

        async.elapse(const Duration(minutes: 1));

        expect(harness.service.calls, hasLength(1));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("failed outcomes retry without redundant listener logging", () {
      fakeAsync((async) {
        final harness = _Harness()..service.immediateOutcome = PrRefreshOutcome.failed;
        final logOutput = _captureLogOutput(
          action: () {
            harness.listener.start();
            harness.tracker.setViewing(connID: 1, projectId: "project-x");
            async.flushMicrotasks();
          },
        );

        expect(logOutput, isNot(contains("Viewed-project pull request refresh failed unexpectedly")));
        async.elapse(const Duration(seconds: 29));
        expect(harness.service.calls, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(harness.service.calls, hasLength(2));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("unexpected errors preserve diagnostics and retry after the interval", () {
      fakeAsync((async) {
        final harness = _Harness()..service.immediateError = StateError("project-x /private/source/path");
        final logOutput = _captureLogOutput(
          action: () {
            harness.listener.start();
            harness.tracker.setViewing(connID: 1, projectId: "project-x");
            async.flushMicrotasks();
          },
        );

        expect(logOutput, contains("Viewed-project pull request refresh failed unexpectedly"));
        expect(logOutput, contains("project-x /private/source/path"));
        expect(logOutput, contains("viewed_project_pr_refresh_listener_test.dart"));

        async.elapse(const Duration(seconds: 30));
        expect(harness.service.calls, hasLength(2));
        _disposeHarness(harness: harness, async: async);
      });
    });

    test("settings stream errors preserve causes and stack paths", () {
      final harness = _Harness();
      final logOutput = _captureLogOutput(
        action: () {
          harness.listener.start();
          harness.settingsService.emitError(
            error: StateError("secret settings cause"),
            stackTrace: StackTrace.fromString("/private/settings/source.dart"),
          );
        },
      );

      expect(logOutput, contains("Pull request refresh settings changes failed unexpectedly"));
      expect(logOutput, contains("secret settings cause"));
      expect(logOutput, contains("/private/settings/source.dart"));
      unawaited(harness.dispose());
    });

    test("dispose drains admitted work and suppresses late completion", () async {
      final harness = _Harness()..service.completeImmediately = false;
      harness.listener.start();
      harness.tracker.setViewing(connID: 1, projectId: "project-x");

      var disposed = false;
      final disposeFuture = harness.listener.dispose().then((_) => disposed = true);
      await Future<void>.delayed(Duration.zero);
      expect(disposed, isFalse);

      harness.service.complete(callIndex: 0);
      await disposeFuture.timeout(const Duration(seconds: 1));
      expect(disposed, isTrue);

      harness.tracker.setViewing(connID: 2, projectId: "project-y");
      await Future<void>.delayed(Duration.zero);
      expect(harness.service.calls, hasLength(1));
      await harness.settingsService.dispose();
      await harness.tracker.dispose();
    });
  });
}

class _Harness() {
  final ProjectViewTracker tracker = ProjectViewTracker();
  final _FakePrSyncService service = _FakePrSyncService();
  final _FakePullRequestRefreshSettingsService settingsService = _FakePullRequestRefreshSettingsService();
  late final ViewedProjectPrRefreshListener listener = ViewedProjectPrRefreshListener(
    tracker: tracker,
    prSyncService: service,
    settingsService: settingsService,
  );

  Future<void> dispose() async {
    await listener.dispose();
    await settingsService.dispose();
    await tracker.dispose();
  }
}

class _FakePullRequestRefreshSettingsService() implements PullRequestRefreshSettingsService {
  final StreamController<PullRequestRefreshSettingsResponse> _changes =
      StreamController<PullRequestRefreshSettingsResponse>.broadcast(sync: true);
  PullRequestRefreshSettingsResponse _current = const PullRequestRefreshSettingsResponse(intervalSeconds: 30);

  @override
  PullRequestRefreshSettingsResponse get currentSettings => _current;

  @override
  Stream<PullRequestRefreshSettingsResponse> get changes => _changes.stream;

  void setInterval({required int intervalSeconds}) {
    _current = PullRequestRefreshSettingsResponse(intervalSeconds: intervalSeconds);
    _changes.add(_current);
  }

  void emitError({required Object error, required StackTrace stackTrace}) {
    _changes.addError(error, stackTrace);
  }

  Future<void> dispose() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePrSyncService() implements PrSyncService {
  final List<({Set<String> projectIds, PrRefreshPolicy refreshPolicy})> calls = [];
  final List<Completer<PrRefreshOutcome>> completions = [];
  bool completeImmediately = true;
  PrRefreshOutcome immediateOutcome = PrRefreshOutcome.completed;
  Object? immediateError;

  @override
  Future<PrRefreshOutcome> triggerRefresh({
    required Set<String> projectIds,
    required PrRefreshPolicy refreshPolicy,
  }) {
    calls.add((projectIds: Set<String>.from(projectIds), refreshPolicy: refreshPolicy));
    final completion = Completer<PrRefreshOutcome>();
    completions.add(completion);
    if (completeImmediately) {
      final error = immediateError;
      immediateError = null;
      if (error == null) {
        completion.complete(immediateOutcome);
      } else {
        completion.completeError(error, StackTrace.current);
      }
    }
    return completion.future;
  }

  void complete({required int callIndex, PrRefreshOutcome outcome = PrRefreshOutcome.completed}) {
    completions[callIndex].complete(outcome);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _disposeHarness({required _Harness harness, required FakeAsync async}) {
  unawaited(harness.dispose());
  async.flushMicrotasks();
}

String _captureLogOutput({required void Function() action}) {
  final output = BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = LogLevel.debug;
    IOOverrides.runZoned(action, stderr: () => output);
  } finally {
    Log.level = previousLevel;
  }
  return output.text;
}
