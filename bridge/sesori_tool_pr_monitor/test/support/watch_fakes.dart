import "dart:async";
import "dart:collection";

import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:sesori_tool_pr_monitor/src/models/pull_request_target.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_merge_outcome.dart";
import "package:sesori_tool_pr_monitor/src/repositories/models/pull_request_snapshot.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_action_repository.dart";
import "package:sesori_tool_pr_monitor/src/repositories/pull_request_snapshot_repository.dart";

/// Answers each fetch with the next queued snapshot or error, or the last
/// snapshot again once the queue is empty.
class FakeSnapshots() implements PullRequestSnapshotRepository {
  final Queue<Object> _next = Queue<Object>();
  final List<PullRequestTarget> fetches = [];
  Object? _last;

  void enqueue(Object snapshotOrError) => _next.add(snapshotOrError);

  @override
  Future<PullRequestSnapshot> fetchSnapshot({required PullRequestTarget target, required String selfLogin}) async {
    fetches.add(target);
    final answer = _next.isEmpty ? _last : _last = _next.removeFirst();
    return switch (answer) {
      final PullRequestSnapshot snapshot => snapshot,
      final Object error => throw error,
      null => throw StateError("no snapshot queued"),
    };
  }
}

/// Records each GitHub write; label changes throw [labelFailure] while set.
class FakeActions() implements PullRequestActionRepository {
  final List<String> calls = [];
  Exception? labelFailure;
  PullRequestMergeOutcome mergeOutcome = const PullRequestMerged(labelError: null);

  /// What [removeReadyLabel] answers.
  bool carriesReadyLabel = true;

  @override
  Future<String> selfLogin() async => "owner";

  @override
  Future<void> addReadyLabel({required PullRequestTarget target}) async {
    calls.add("add label");
    if (labelFailure case final failure?) throw failure;
  }

  @override
  Future<bool> removeReadyLabel({required PullRequestTarget target}) async {
    calls.add("remove label");
    if (labelFailure case final failure?) throw failure;
    return carriesReadyLabel;
  }

  @override
  Future<PullRequestMergeOutcome> squashMerge({
    required PullRequestTarget target,
    required String headSha,
    required String title,
  }) async {
    calls.add("merge $headSha");
    return mergeOutcome;
  }

  @override
  Future<String> reply({required PullRequestTarget target, required String? threadId, required String body}) async {
    calls.add("reply ${threadId ?? "comment"}: $body");
    return "https://github.com/sesori/example/pull/42#reply";
  }
}

class MemoryStore() implements SesoriToolStore {
  /// By session id, then key.
  final Map<String, Map<String, Map<String, Object?>>> sessionRecords = {};

  @override
  Future<Map<String, Object?>?> getSessionRecord({required String sessionId, required String key}) async =>
      sessionRecords[sessionId]?[key];

  @override
  Future<void> putSessionRecord({
    required String sessionId,
    required String key,
    required Map<String, Object?> value,
  }) async => (sessionRecords[sessionId] ??= {})[key] = value;

  @override
  Future<bool> deleteSessionRecord({required String sessionId, required String key}) async =>
      sessionRecords[sessionId]?.remove(key) != null;

  @override
  Future<Map<String, Map<String, Object?>>> listRecordsOfSession({required String sessionId}) async => {
    ...?sessionRecords[sessionId],
  };

  @override
  Future<List<SesoriToolSessionRecord>> listSessionRecords() async => [
    for (final MapEntry(key: sessionId, value: records) in sessionRecords.entries)
      for (final MapEntry(:key, :value) in records.entries)
        SesoriToolSessionRecord(sessionId: sessionId, key: key, value: value),
  ];

  /// The group's bridge records, by key.
  final Map<String, Map<String, Object?>> records = {};

  @override
  Future<Map<String, Object?>?> getRecord({required String key}) async => records[key];

  @override
  Future<void> putRecord({required String key, required Map<String, Object?> value}) async => records[key] = value;

  @override
  Future<bool> deleteRecord({required String key}) => throw UnimplementedError();

  @override
  Future<Map<String, Map<String, Object?>>> listRecords() => throw UnimplementedError();
}

class SentNotice({
  required final String sessionId,
  required final String summary,
  required final String guidance,
  required final SesoriToolNoticeTiming timing,
}) {
  @override
  String toString() => "$sessionId: $summary";
}

/// An Allow request shown to the user; [answer] answers it.
class AskedApproval({
  required final String sessionId,
  required final String title,
  required final String body,
  required final Completer<SesoriToolApprovalOutcome> answer,
});

/// Delivers each notice at once, running its claim, unless [hold] is set:
/// then the notice waits until [release]. Shows each Allow request in
/// [asked], unless [approvesEverything].
class FakeHost({required final MemoryStore records}) implements SesoriToolHost {
  final Map<String, SesoriToolSession> knownSessions = {};
  final List<SentNotice> sent = [];
  final List<SesoriToolNoticeOutcome> outcomes = [];
  bool hold = false;
  bool approvesEverything = false;
  final List<AskedApproval> asked = [];
  SesoriToolNoticeOutcome? forcedOutcome;
  final List<void Function()> _held = [];

  @override
  bool enabled = true;

  @override
  Stream<bool> get enabledChanges => const Stream.empty();

  void addSession({required String sessionId, String? rootSessionId}) => knownSessions[sessionId] = SesoriToolSession(
    rootSessionId: rootSessionId ?? sessionId,
    workingDirectory: "/repo",
    archived: false,
  );

  /// Runs every held notice's claim and send.
  void release() {
    final held = [..._held];
    _held.clear();
    for (final send in held) {
      send();
    }
  }

  @override
  Future<SesoriToolNoticeOutcome> deliverNotice({
    required String sessionId,
    required String summary,
    required String guidance,
    required SesoriToolNoticeTiming timing,
    required Future<bool> Function()? claim,
  }) {
    final done = Completer<SesoriToolNoticeOutcome>();
    Future<void> send() async {
      final forced = forcedOutcome;
      // A forced drop models a send that fails after its claim ran.
      if (forced == SesoriToolNoticeOutcome.dropped && claim != null) await claim();
      final outcome =
          forced ?? (claim == null || await claim() ? SesoriToolNoticeOutcome.sent : SesoriToolNoticeOutcome.claimLost);
      if (outcome == SesoriToolNoticeOutcome.sent) {
        sent.add(SentNotice(sessionId: sessionId, summary: summary, guidance: guidance, timing: timing));
      }
      outcomes.add(outcome);
      done.complete(outcome);
    }

    if (hold) {
      _held.add(() => unawaited(send()));
    } else {
      unawaited(send());
    }
    return done.future;
  }

  @override
  Future<Map<String, SesoriToolSession>> sessions({required Set<String> sessionIds}) async => {
    for (final id in sessionIds) id: ?knownSessions[id],
  };

  @override
  Future<SesoriToolApproval> requestApproval({
    required String sessionId,
    required String title,
    required String body,
  }) async {
    if (approvesEverything) return const SesoriToolApprovalAllowed();
    final answer = Completer<SesoriToolApprovalOutcome>();
    asked.add(AskedApproval(sessionId: sessionId, title: title, body: body, answer: answer));
    return SesoriToolApprovalShown(answer: answer.future);
  }

  @override
  SesoriToolStore get store => records;
}
