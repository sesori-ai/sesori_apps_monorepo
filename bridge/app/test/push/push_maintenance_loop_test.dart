import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_maintenance_loop.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker_models.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PushMaintenanceLoop", () {
    test("construction: schedules periodic maintenance on the provided cadence", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 2),
        );
        addTearDown(harness.dispose);

        expect(harness.loop.lastSnapshot, isNull);
        expect(harness.tracker.findPrunableRootsCalls, equals(0));
        expect(harness.telemetryBuilder.buildCalls, isEmpty);

        async.elapse(const Duration(minutes: 1, seconds: 59));
        async.flushMicrotasks();

        expect(harness.loop.lastSnapshot, isNull);
        expect(harness.tracker.findPrunableRootsCalls, equals(0));

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(harness.tracker.findPrunableRootsCalls, equals(1));
        expect(harness.tracker.pruneMessageRoleMetadataCalls, equals(1));
        expect(harness.rateLimiter.pruneStaleEntriesCalls, equals(1));
        expect(harness.telemetryBuilder.buildCalls, hasLength(1));
        expect(harness.loop.lastSnapshot, same(harness.telemetryBuilder.snapshot));
      });
    });

    test("runNow rootPrune: prunes each root and cleans notifier state", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.tracker.prunableRoots = <PushPrunableRoot>[
        PushPrunableRoot(
          rootSessionId: "root-a",
          idleSince: DateTime.utc(2026, 1, 1, 12),
          retainedSessionCount: 2,
        ),
        PushPrunableRoot(
          rootSessionId: "root-b",
          idleSince: DateTime.utc(2026, 1, 1, 12, 5),
          retainedSessionCount: 1,
        ),
      ];
      harness.tracker.pruneResults["root-a"] = const PushPrunedSubtree(
        rootSessionId: "root-a",
        prunedSessionIds: <String>["child-a"],
        removedSessionCount: 2,
        removedMessageRoleCount: 1,
        removedPermissionMappingCount: 1,
      );
      harness.tracker.pruneResults["root-b"] = const PushPrunedSubtree(
        rootSessionId: "root-b",
        prunedSessionIds: <String>[],
        removedSessionCount: 1,
        removedMessageRoleCount: 0,
        removedPermissionMappingCount: 0,
      );

      harness.loop.runNow();

      expect(harness.tracker.findPrunableRootsCalls, equals(1));
      expect(harness.tracker.pruneRootSubtreeCalls, equals(<String>["root-a", "root-b"]));
      expect(harness.notifier.cleanupCalls, hasLength(2));
      expect(harness.notifier.cleanupCalls[0].rootSessionId, equals("root-a"));
      expect(harness.notifier.cleanupCalls[0].prunedSessionIds, equals(<String>["child-a"]));
      expect(harness.notifier.cleanupCalls[1].rootSessionId, equals("root-b"));
      expect(harness.notifier.cleanupCalls[1].prunedSessionIds, isEmpty);
    });

    test("runNow messageRolePrune: delegates message role pruning to tracker", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.loop.runNow();

      expect(harness.tracker.pruneMessageRoleMetadataCalls, equals(1));
    });

    test("runNow rateLimiterPrune: delegates stale entry pruning to the rate limiter", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.loop.runNow();

      expect(harness.rateLimiter.pruneStaleEntriesCalls, equals(1));
    });

    test("runNow telemetry: builds stores and logs the telemetry snapshot", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      final stdout = _captureStdout(
        level: LogLevel.debug,
        action: harness.loop.runNow,
      );

      expect(harness.tracker.createTelemetrySnapshotCalls, equals(1));
      expect(harness.telemetryBuilder.buildCalls, hasLength(1));
      expect(
        harness.telemetryBuilder.buildCalls.single,
        same(harness.tracker.telemetrySnapshot),
      );
      expect(harness.loop.lastSnapshot, same(harness.telemetryBuilder.snapshot));
      expect(stdout, contains(harness.telemetryBuilder.snapshot.toLogMessage()));
    });

    test("runNow errorHandling: logs a warning and continues after a root prune failure", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.tracker.prunableRoots = <PushPrunableRoot>[
        PushPrunableRoot(
          rootSessionId: "root-a",
          idleSince: DateTime.utc(2026, 1, 1, 12),
          retainedSessionCount: 2,
        ),
        PushPrunableRoot(
          rootSessionId: "root-b",
          idleSince: DateTime.utc(2026, 1, 1, 12, 5),
          retainedSessionCount: 1,
        ),
        PushPrunableRoot(
          rootSessionId: "root-c",
          idleSince: DateTime.utc(2026, 1, 1, 12, 10),
          retainedSessionCount: 1,
        ),
      ];
      harness.tracker.pruneResults["root-a"] = const PushPrunedSubtree(
        rootSessionId: "root-a",
        prunedSessionIds: <String>["child-a"],
        removedSessionCount: 2,
        removedMessageRoleCount: 0,
        removedPermissionMappingCount: 0,
      );
      harness.tracker.pruneResults["root-c"] = const PushPrunedSubtree(
        rootSessionId: "root-c",
        prunedSessionIds: <String>["child-c"],
        removedSessionCount: 1,
        removedMessageRoleCount: 0,
        removedPermissionMappingCount: 0,
      );
      harness.tracker.throwOnPruneRootIds.add("root-b");

      final stdout = _captureStdout(
        level: LogLevel.warning,
        action: harness.loop.runNow,
      );

      expect(stdout, contains("[push] maintenance step 'root-prune:root-b' failed:"));
      expect(harness.tracker.pruneRootSubtreeCalls, equals(<String>["root-a", "root-b", "root-c"]));
      expect(harness.notifier.cleanupCalls, hasLength(2));
      expect(harness.notifier.cleanupCalls[0].rootSessionId, equals("root-a"));
      expect(harness.notifier.cleanupCalls[1].rootSessionId, equals("root-c"));
      expect(harness.tracker.pruneMessageRoleMetadataCalls, equals(1));
      expect(harness.rateLimiter.pruneStaleEntriesCalls, equals(1));
      expect(harness.telemetryBuilder.buildCalls, hasLength(1));
      expect(harness.loop.lastSnapshot, same(harness.telemetryBuilder.snapshot));
    });

    test("runNow telemetryFailure: logs a warning and preserves the prior snapshot", () {
      final harness = _newHarness();
      addTearDown(harness.dispose);

      harness.loop.runNow();
      final firstSnapshot = harness.loop.lastSnapshot;
      expect(firstSnapshot, same(harness.telemetryBuilder.snapshot));

      harness.telemetryBuilder.throwOnBuild = true;
      final stdout = _captureStdout(
        level: LogLevel.warning,
        action: harness.loop.runNow,
      );

      expect(stdout, contains("[push] maintenance step 'telemetry' failed:"));
      expect(harness.loop.lastSnapshot, same(firstSnapshot));
    });

    test("dispose: cancels the periodic timer", () {
      fakeAsync((async) {
        final harness = _newHarness(
          maintenanceInterval: const Duration(minutes: 1),
        );
        addTearDown(harness.dispose);

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(harness.telemetryBuilder.buildCalls, hasLength(1));

        harness.loop.dispose();

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(harness.telemetryBuilder.buildCalls, hasLength(1));
      });
    });
  });
}

class _Harness {
  final PushMaintenanceLoop loop;
  final SpyPushSessionStateTracker tracker;
  final SpyCompletionNotifier notifier;
  final SpyPushRateLimiter rateLimiter;
  final SpyPushMaintenanceTelemetryBuilder telemetryBuilder;

  _Harness({
    required this.loop,
    required this.tracker,
    required this.notifier,
    required this.rateLimiter,
    required this.telemetryBuilder,
  });

  void dispose() {
    loop.dispose();
    notifier.dispose();
  }
}

_Harness _newHarness({
  SpyPushSessionStateTracker? tracker,
  SpyCompletionNotifier? notifier,
  SpyPushRateLimiter? rateLimiter,
  SpyPushMaintenanceTelemetryBuilder? telemetryBuilder,
  Duration maintenanceInterval = const Duration(minutes: 10),
}) {
  final resolvedTracker = tracker ?? SpyPushSessionStateTracker();
  final resolvedNotifier = notifier ?? SpyCompletionNotifier(tracker: resolvedTracker);
  final resolvedRateLimiter = rateLimiter ?? SpyPushRateLimiter();
  final resolvedTelemetryBuilder =
      telemetryBuilder ??
      SpyPushMaintenanceTelemetryBuilder(
        completionNotifier: resolvedNotifier,
        rateLimiter: resolvedRateLimiter,
      );
  final loop = PushMaintenanceLoop(
    tracker: resolvedTracker,
    completionNotifier: resolvedNotifier,
    rateLimiter: resolvedRateLimiter,
    telemetryBuilder: resolvedTelemetryBuilder,
    maintenanceInterval: maintenanceInterval,
  );

  return _Harness(
    loop: loop,
    tracker: resolvedTracker,
    notifier: resolvedNotifier,
    rateLimiter: resolvedRateLimiter,
    telemetryBuilder: resolvedTelemetryBuilder,
  );
}

class SpyPushSessionStateTracker extends PushSessionStateTracker {
  int findPrunableRootsCalls = 0;
  int pruneMessageRoleMetadataCalls = 0;
  int createTelemetrySnapshotCalls = 0;
  List<PushPrunableRoot> prunableRoots = <PushPrunableRoot>[];
  final Map<String, PushPrunedSubtree> pruneResults = <String, PushPrunedSubtree>{};
  final Set<String> throwOnPruneRootIds = <String>{};
  final List<String> pruneRootSubtreeCalls = <String>[];
  PushSessionTelemetrySnapshot telemetrySnapshot = _trackerSnapshot();

  SpyPushSessionStateTracker() : super(now: _fixedNow);

  static DateTime _fixedNow() {
    return DateTime.utc(2026, 1, 1, 12);
  }

  @override
  List<PushPrunableRoot> findPrunableRoots() {
    findPrunableRootsCalls += 1;
    return prunableRoots;
  }

  @override
  PushPrunedSubtree pruneRootSubtree({required String rootSessionId}) {
    pruneRootSubtreeCalls.add(rootSessionId);
    if (throwOnPruneRootIds.contains(rootSessionId)) {
      throw StateError("pruneRootSubtree boom for $rootSessionId");
    }

    return pruneResults[rootSessionId] ??
        PushPrunedSubtree(
          rootSessionId: rootSessionId,
          prunedSessionIds: const <String>[],
          removedSessionCount: 0,
          removedMessageRoleCount: 0,
          removedPermissionMappingCount: 0,
        );
  }

  @override
  void pruneMessageRoleMetadata() {
    pruneMessageRoleMetadataCalls += 1;
  }

  @override
  PushSessionTelemetrySnapshot createTelemetrySnapshot() {
    createTelemetrySnapshotCalls += 1;
    return telemetrySnapshot;
  }
}

class SpyCompletionNotifier extends CompletionNotifier {
  final List<({String rootSessionId, List<String> prunedSessionIds})> cleanupCalls =
      <({String rootSessionId, List<String> prunedSessionIds})>[];

  SpyCompletionNotifier({required super.tracker}) : super(debounceDuration: const Duration(milliseconds: 500));

  @override
  void cleanupPrunedRootSubtree({
    required String rootSessionId,
    required Iterable<String> prunedSessionIds,
  }) {
    cleanupCalls.add(
      (
        rootSessionId: rootSessionId,
        prunedSessionIds: prunedSessionIds.toList(growable: false),
      ),
    );
  }
}

class SpyPushRateLimiter extends PushRateLimiter {
  int pruneStaleEntriesCalls = 0;

  SpyPushRateLimiter() : super(now: _fixedNow);

  static DateTime _fixedNow() {
    return DateTime.utc(2026, 1, 1, 12);
  }

  @override
  int pruneStaleEntries({Duration ttl = PushRateLimiter.staleEntryTtl}) {
    pruneStaleEntriesCalls += 1;
    return 0;
  }
}

class SpyPushMaintenanceTelemetryBuilder extends PushMaintenanceTelemetryBuilder {
  final List<PushSessionTelemetrySnapshot> buildCalls = <PushSessionTelemetrySnapshot>[];
  bool throwOnBuild = false;
  PushMaintenanceTelemetrySnapshot snapshot;

  SpyPushMaintenanceTelemetryBuilder({
    required super.completionNotifier,
    required super.rateLimiter,
    PushMaintenanceTelemetrySnapshot? snapshot,
  }) : snapshot = snapshot ?? _maintenanceSnapshot(),
       super(rssBytesReader: _readNothing);

  static int? _readNothing() {
    return null;
  }

  @override
  PushMaintenanceTelemetrySnapshot build({required PushSessionTelemetrySnapshot trackerSnapshot}) {
    buildCalls.add(trackerSnapshot);
    if (throwOnBuild) {
      throw StateError("telemetry build boom");
    }

    return snapshot;
  }
}

class _BufferingStdout implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void write(Object? object) {
    _buffer.write(object);
  }

  @override
  void writeln([Object? object = ""]) {
    _buffer.writeln(object);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

String _captureStdout({required LogLevel level, required void Function() action}) {
  final stdoutBuffer = _BufferingStdout();
  final stderrBuffer = _BufferingStdout();
  final previousLevel = Log.level;
  try {
    Log.level = level;
    IOOverrides.runZoned(
      action,
      stdout: () => stdoutBuffer,
      stderr: () => stderrBuffer,
    );
  } finally {
    Log.level = previousLevel;
  }

  return stdoutBuffer.text;
}

PushSessionTelemetrySnapshot _trackerSnapshot() {
  return const PushSessionTelemetrySnapshot(
    sessionCount: 2,
    rootSessionCount: 1,
    idleRootCount: 1,
    busySessionCount: 0,
    pendingQuestionCount: 0,
    pendingPermissionCount: 0,
    permissionRequestCount: 0,
    previouslyBusyCount: 1,
    latestAssistantTextCount: 1,
    latestAssistantTextCharCount: 4,
    messageRoleCount: 1,
    assistantMessageRoleCount: 1,
    oldestSessionActivityAt: null,
    oldestMessageRoleUpdatedAt: null,
    prunableRoots: <PushPrunableRoot>[],
  );
}

PushMaintenanceTelemetrySnapshot _maintenanceSnapshot() {
  return const PushMaintenanceTelemetrySnapshot(
    rssMb: 2.5,
    sessions: 2,
    idleRoots: 1,
    prunableRoots: 0,
    messageRoles: 1,
    assistantTextSessions: 1,
    assistantTextChars: 4,
    trackerPermissionRequests: 0,
    notifierPermissionRequests: 0,
    completionSentRoots: 0,
    abortedRoots: 0,
    rateLimiterKeys: 0,
  );
}
