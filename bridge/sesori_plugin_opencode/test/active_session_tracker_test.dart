import "package:opencode_plugin/opencode_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ActiveSessionTracker", () {
    test("empty tracker has empty activeSessions", () {
      final tracker = ActiveSessionTracker(_fakeRepository());
      expect(tracker.activeSessions, isEmpty);
    });

    test("empty tracker buildSummary returns empty list", () {
      final tracker = ActiveSessionTracker(_fakeRepository());
      expect(tracker.buildSummary(), isEmpty);
    });

    group("session directory registration", () {
      test("registerSession stores directory for lookup", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        tracker.registerSession(sessionId: "s1", directory: "/projects/foo");

        expect(tracker.getSessionDirectory(sessionId: "s1"), equals("/projects/foo"));
      });

      test("getSessionDirectory returns null for unknown session", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        expect(tracker.getSessionDirectory(sessionId: "missing"), isNull);
      });

      test("registerSession preserves raw directory without worktree normalization", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        tracker.registerSession(sessionId: "s1", directory: "/projects/foo/packages/bar");

        expect(
          tracker.getSessionDirectory(sessionId: "s1"),
          equals("/projects/foo/packages/bar"),
        );
      });

      test("SSE session.created populates getSessionDirectory", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
        );

        tracker.handleEvent(
          _sessionCreated("s1", "/projects/foo/packages/bar"),
          null,
        );

        expect(
          tracker.getSessionDirectory(sessionId: "s1"),
          equals("/projects/foo/packages/bar"),
        );
      });

      test("SSE session.updated preserves raw directory", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
        );

        tracker.handleEvent(
          _sessionCreated("s1", "/projects/foo/packages/bar"),
          null,
        );
        tracker.handleEvent(
          _sessionUpdated("s1", "/projects/foo/packages/bar"),
          null,
        );

        expect(
          tracker.getSessionDirectory(sessionId: "s1"),
          equals("/projects/foo/packages/bar"),
        );
      });

      test("SSE session.deleted removes from getSessionDirectory", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
        expect(tracker.getSessionDirectory(sessionId: "s1"), equals("/projects/foo"));

        tracker.handleEvent(_sessionDeleted("s1"), null);

        expect(tracker.getSessionDirectory(sessionId: "s1"), isNull);
      });

      test("coldStart populates getSessionDirectory for all fetched sessions", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
          sessions: [
            _session("s1", "/projects/foo"),
            _session("s2", "/projects/foo/lib"),
          ],
        );

        expect(tracker.getSessionDirectory(sessionId: "s1"), equals("/projects/foo"));
        expect(tracker.getSessionDirectory(sessionId: "s2"), equals("/projects/foo/lib"));
      });

      test("reset clears session directories", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        tracker.registerSession(sessionId: "s1", directory: "/projects/foo");
        expect(tracker.getSessionDirectory(sessionId: "s1"), isNotNull);

        tracker.reset();

        expect(tracker.getSessionDirectory(sessionId: "s1"), isNull);
      });

      test("resolveProjectWorktree returns canonical root for subdirectory sessions", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        tracker.updateProjectWorktrees(worktrees: {"/repo"});

        expect(
          tracker.resolveProjectWorktree(directory: "/repo/packages/foo"),
          equals("/repo"),
        );
      });
    });

    group("getActiveStatuses", () {
      test("empty tracker returns empty map", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        expect(tracker.getActiveStatuses(), isEmpty);
      });

      test("coldStart populates active statuses from busy/retry sessions", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
          sessions: [
            _session("s1", "/projects/foo"),
            _session("s2", "/projects/foo"),
            _session("s3", "/projects/foo"),
          ],
          statuses: {
            "s1": const SessionStatus.busy(),
            "s2": const SessionStatus.idle(),
            "s3": const SessionStatus.retry(attempt: 1, message: "fail", next: 123),
          },
        );

        final active = tracker.getActiveStatuses();

        expect(active, hasLength(2));
        expect(active["s1"], isA<SessionStatusBusy>());
        expect(active["s3"], isA<SessionStatusRetry>());
        expect(active.containsKey("s2"), isFalse);
      });

      test("SSE busy event adds to active statuses", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        final active = tracker.getActiveStatuses();

        expect(active, hasLength(1));
        expect(active["s1"], isA<SessionStatusBusy>());
      });

      test("SSE idle event removes from active statuses", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
          sessions: [_session("s1", "/projects/foo")],
          statuses: {"s1": const SessionStatus.busy()},
        );
        expect(tracker.getActiveStatuses(), hasLength(1));

        tracker.handleEvent(_sessionIdle("s1"), null);

        expect(tracker.getActiveStatuses(), isEmpty);
      });

      test("returns unmodifiable map", () {
        final tracker = ActiveSessionTracker(_fakeRepository());

        final active = tracker.getActiveStatuses();

        expect(() => active["x"] = const SessionStatus.busy(), throwsA(anything));
      });

      test("reset clears active statuses", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/projects/foo")],
          sessions: [_session("s1", "/projects/foo")],
          statuses: {"s1": const SessionStatus.busy()},
        );
        expect(tracker.getActiveStatuses(), hasLength(1));

        tracker.reset();

        expect(tracker.getActiveStatuses(), isEmpty);
      });
    });

    test("session directory exactly matches worktree", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/projects/foo": 1}));
    });

    test("session directory as subdirectory resolves to project", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo/lib/src"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/projects/foo": 1}));
    });

    test("session directory with no matching worktree is ignored", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/tmp/other"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), "/tmp/other");

      expect(changed, isFalse);
      expect(tracker.activeSessions, isEmpty);
    });

    test("empty directory is handled gracefully", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", ""), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), "");

      expect(changed, isFalse);
      expect(tracker.activeSessions, isEmpty);
    });

    test("longest matching worktree is selected", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/projects/foo"),
          const Project(id: "p2", worktree: "/projects/foo/packages/bar"),
        ],
      );

      tracker.handleEvent(
        _sessionCreated("s1", "/projects/foo/packages/bar/src"),
        null,
      );
      tracker.handleEvent(_sessionBusy("s1"), null);

      tracker.handleEvent(_sessionCreated("s2", "/projects/foo/lib"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      expect(
        tracker.activeSessions,
        equals({"/projects/foo/packages/bar": 1, "/projects/foo": 1}),
      );
    });

    test("windows-style path prefixes resolve to project", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: r"C:\repo\foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", r"C:\repo\foo\subdir"), null);
      final changed = tracker.handleEvent(_sessionBusy("s1"), null);

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({r"C:\repo\foo": 1}));
    });

    test("busy increments and idle decrements active count", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);

      final busyChanged = tracker.handleEvent(_sessionBusy("s1"), null);
      expect(busyChanged, isTrue);
      expect(tracker.activeSessions, equals({"/repo": 1}));

      final idleChanged = tracker.handleEvent(_sessionIdle("s1"), null);
      expect(idleChanged, isTrue);
      expect(tracker.activeSessions, isEmpty);
    });

    test("retry session status counts as active", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      final changed = tracker.handleEvent(
        const SseEventData.sessionStatus(
          sessionID: "s1",
          status: SessionStatus.retry(
            attempt: 2,
            message: "retrying",
            next: 123,
          ),
        ),
        null,
      );

      expect(changed, isTrue);
      expect(tracker.activeSessions, equals({"/repo": 1}));
    });

    test("multiple busy sessions in same project are all counted", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionCreated("s2", "/repo/lib"), null);

      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      expect(tracker.activeSessions, equals({"/repo": 2}));
    });

    test(
      "deleted session is removed from maps and active count updates",
      () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        expect(tracker.activeSessions, equals({"/repo": 1}));

        final changed = tracker.handleEvent(
          _sessionDeleted("s1", "/repo"),
          null,
        );
        expect(changed, isTrue);
        expect(tracker.activeSessions, isEmpty);

        final afterDeleteStatus = tracker.handleEvent(_sessionBusy("s1"), null);
        expect(afterDeleteStatus, isFalse);
        expect(tracker.activeSessions, isEmpty);
      },
    );

    test(
      "unknown directory on status event does not crash and returns false",
      () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        final changed = tracker.handleEvent(_sessionBusy("s1"), "/tmp/unknown");

        expect(changed, isFalse);
        expect(tracker.activeSessions, isEmpty);
      },
    );

    test("reset clears all state", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      expect(tracker.activeSessions, equals({"/repo": 1}));

      tracker.reset();

      expect(tracker.activeSessions, isEmpty);
      expect(tracker.buildSummary(), isEmpty);
    });

    test("buildSummary includes only projects with active sessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/repo-a"),
          const Project(id: "p2", worktree: "/repo-b"),
        ],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo-a"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);

      final summary = tracker.buildSummary();
      final pairs = summary.map((item) => (item.id, item.activeSessions.length)).toSet();

      expect(pairs, equals({("/repo-a", 1)}));
    });

    test("handleEvent change detection and idempotency", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);

      final changedOnBusy = tracker.handleEvent(_sessionBusy("s1"), null);
      expect(changedOnBusy, isTrue);

      final unchangedOnNonSession = tracker.handleEvent(
        const SseEventData.serverHeartbeat(),
        null,
      );
      expect(unchangedOnNonSession, isFalse);

      final unchangedOnDuplicate = tracker.handleEvent(
        _sessionBusy("s1"),
        null,
      );
      expect(unchangedOnDuplicate, isFalse);
    });

    test("coldStart populates state from API", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/foo"),
          const Project(id: "p2", worktree: "/bar"),
        ],
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/foo"),
          const Session(id: "s2", projectID: "p2", directory: "/bar"),
        ],
        statuses: {"s1": const SessionStatus.busy(), "s2": const SessionStatus.idle()},
      );

      expect(tracker.activeSessions, equals({"/foo": 1}));
    });

    test("coldStart buildSummary reflects busy sessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/repo"),
        ],
        statuses: {"s1": const SessionStatus.busy()},
      );

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.id, equals("/repo"));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.mainAgentRunning, isTrue);
    });

    test("coldStart groups child sessions under parents", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/repo"),
          const Session(id: "c1", projectID: "p1", directory: "/repo", parentID: "s1"),
        ],
        statuses: {"c1": const SessionStatus.busy()},
      );

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.mainAgentRunning, isFalse);
      expect(summary.first.activeSessions.first.childSessionIds, equals(["c1"]));
    });

    test("buildSummary includes activeSessions for busy sessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.map((s) => s.id), unorderedEquals(["s1", "s2"]));
      expect(summary.first.activeSessions.length, equals(2));
    });

    test("buildSummary excludes idle sessions from activeSessions", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/projects/foo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);
      tracker.handleEvent(_sessionIdle("s1"), null);

      final summary = tracker.buildSummary();

      expect(summary.first.activeSessions.map((s) => s.id), equals(["s2"]));
      expect(summary.first.activeSessions.length, equals(1));
    });

    test("buildSummary groups session IDs by worktree correctly", () async {
      final tracker = await _coldStartedTracker(
        projects: [
          const Project(id: "p1", worktree: "/projects/foo"),
          const Project(id: "p2", worktree: "/projects/bar"),
        ],
      );

      tracker.handleEvent(_sessionCreated("s1", "/projects/foo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(_sessionCreated("s2", "/projects/bar"), null);
      tracker.handleEvent(_sessionBusy("s2"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(2));

      final fooEntry = summary.firstWhere((e) => e.id == "/projects/foo");
      final barEntry = summary.firstWhere((e) => e.id == "/projects/bar");

      expect(fooEntry.activeSessions.map((s) => s.id), equals(["s1"]));
      expect(barEntry.activeSessions.map((s) => s.id), equals(["s2"]));
    });

    test("child sessions are grouped under their parent", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "c1", projectID: "project", directory: "/repo", parentID: "s1"),
        ),
        null,
      );
      tracker.handleEvent(_sessionBusy("c1"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.length, equals(1));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.mainAgentRunning, isTrue);
      expect(summary.first.activeSessions.first.childSessionIds, equals(["c1"]));
    });

    test("idle root with busy children appears in summary", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "c1", projectID: "project", directory: "/repo", parentID: "s1"),
        ),
        null,
      );
      tracker.handleEvent(_sessionBusy("c1"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.length, equals(1));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.mainAgentRunning, isFalse);
      expect(summary.first.activeSessions.first.childSessionIds, equals(["c1"]));
    });

    test("orphan child sessions are ignored", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "c1", projectID: "project", directory: "/repo", parentID: "unknown"),
        ),
        null,
      );
      tracker.handleEvent(_sessionBusy("c1"), null);

      final summary = tracker.buildSummary();

      expect(summary, isEmpty);
    });

    test("coldStart resolves busy child sessions not in root list", () async {
      // Regression: coldStart used to call listRootSessions() which omitted
      // child sessions.  A busy child would have no directory / parentId and
      // be treated as an orphan root, logging "no worktree for session".
      // After switching to listSessions(), child metadata is available.
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
        sessions: [
          const Session(id: "s1", projectID: "p1", directory: "/repo"),
          const Session(id: "c1", projectID: "p1", directory: "/repo", parentID: "s1"),
        ],
        statuses: {"c1": const SessionStatus.busy()},
      );

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.mainAgentRunning, isFalse);
      expect(summary.first.activeSessions.first.childSessionIds, equals(["c1"]));
    });

    test("deeply nested children are ignored", () async {
      final tracker = await _coldStartedTracker(
        projects: [const Project(id: "p1", worktree: "/repo")],
      );

      tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
      tracker.handleEvent(_sessionBusy("s1"), null);
      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "c1", projectID: "project", directory: "/repo", parentID: "s1"),
        ),
        null,
      );
      tracker.handleEvent(_sessionBusy("c1"), null);
      tracker.handleEvent(
        const SseEventData.sessionCreated(
          info: Session(id: "g1", projectID: "project", directory: "/repo", parentID: "c1"),
        ),
        null,
      );
      tracker.handleEvent(_sessionBusy("g1"), null);

      final summary = tracker.buildSummary();

      expect(summary, hasLength(1));
      expect(summary.first.activeSessions.length, equals(1));
      expect(summary.first.activeSessions.first.id, equals("s1"));
      expect(summary.first.activeSessions.first.childSessionIds, equals(["c1"]));
    });

    group("pending input tracking", () {
      test("question asked sets awaitingInput true, replied clears it", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        tracker.handleEvent(_questionAsked("q1", "s1"), null);

        final summary = tracker.buildSummary();
        expect(summary.first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_questionReplied("q1", "s1"), null);

        final afterReply = tracker.buildSummary();
        expect(afterReply.first.activeSessions.first.awaitingInput, isFalse);
      });

      test("question rejected clears awaitingInput", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        tracker.handleEvent(_questionAsked("q1", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_questionRejected("q1", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isFalse);
      });

      test("permission asked sets awaitingInput, replied clears it via requestID mapping", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        tracker.handleEvent(_permissionAsked("p1", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_permissionReplied(requestId: "p1", sessionId: "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isFalse);
      });

      test("multiple pending questions require all resolved to clear", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        tracker.handleEvent(_questionAsked("q1", "s1"), null);
        tracker.handleEvent(_questionAsked("q2", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_questionReplied("q1", "s1"), null);

        // One question still pending.
        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_questionReplied("q2", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isFalse);
      });

      test("session deleted cleans up pending input state", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        tracker.handleEvent(_questionAsked("q1", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_sessionDeleted("s1", "/repo"), null);

        // Session gone — no summary entries at all.
        expect(tracker.buildSummary(), isEmpty);
      });

      test("session idle cleans up pending input state", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        tracker.handleEvent(_questionAsked("q1", "s1"), null);

        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isTrue);

        tracker.handleEvent(_sessionIdle("s1"), null);

        // Session no longer active — summary empty.
        expect(tracker.buildSummary(), isEmpty);
      });

      test("question asked on active session triggers change detection", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        // Active session count unchanged, but pending input state changed.
        final changed = tracker.handleEvent(_questionAsked("q1", "s1"), null);

        expect(changed, isTrue);
      });

      test("populatePendingQuestions populates from cold start data", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
          sessions: [_session("s1", "/repo")],
          statuses: {"s1": const SessionStatus.busy()},
        );

        tracker.populatePendingQuestions(
          questions: [
            const PendingQuestion(id: "q1", sessionID: "s1", questions: []),
          ],
        );

        final summary = tracker.buildSummary();
        expect(summary.first.activeSessions.first.awaitingInput, isTrue);
      });

      test("permission replied for unknown requestID is a no-op", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/repo"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        // Reply to a permission that was never asked — should not crash.
        final changed = tracker.handleEvent(_permissionReplied(requestId: "unknown", sessionId: "s1"), null);

        expect(changed, isFalse);
        expect(tracker.buildSummary().first.activeSessions.first.awaitingInput, isFalse);
      });

      test("child session pending question bubbles up to root awaitingInput", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("root", "/repo"), null);
        tracker.handleEvent(_sessionBusy("root"), null);

        // Register child session under root, mark it busy.
        tracker.handleEvent(_childSessionCreated("child", "root", "/repo"), null);
        tracker.handleEvent(_sessionBusy("child"), null);

        // Question asked on child — root should show awaitingInput.
        final changed = tracker.handleEvent(_questionAsked("q1", "child"), null);

        expect(changed, isTrue, reason: "bubble-up must trigger re-emit");
        final summary = tracker.buildSummary();
        final rootSession = summary.first.activeSessions.firstWhere((s) => s.id == "root");
        expect(rootSession.awaitingInput, isTrue, reason: "child question must bubble to root");
      });

      test("child session pending permission bubbles up to root awaitingInput", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
        );

        tracker.handleEvent(_sessionCreated("root", "/repo"), null);
        tracker.handleEvent(_sessionBusy("root"), null);
        tracker.handleEvent(_childSessionCreated("child", "root", "/repo"), null);
        tracker.handleEvent(_sessionBusy("child"), null);

        tracker.handleEvent(_permissionAsked("p1", "child"), null);

        final summary = tracker.buildSummary();
        final rootSession = summary.first.activeSessions.firstWhere((s) => s.id == "root");
        expect(rootSession.awaitingInput, isTrue);

        // Resolving the child permission should clear the root's awaitingInput.
        tracker.handleEvent(_permissionReplied(requestId: "p1", sessionId: "child"), null);
        final afterSummary = tracker.buildSummary();
        final afterRoot = afterSummary.first.activeSessions.firstWhere((s) => s.id == "root");
        expect(afterRoot.awaitingInput, isFalse);
      });

      test("populatePendingPermissions hydrates from cold start data", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/repo")],
          statuses: {"s1": const SessionStatus.busy()},
          sessions: [
            const Session(id: "s1", projectID: "p1", directory: "/repo"),
          ],
        );

        tracker.populatePendingPermissions(
          permissions: [
            const PendingPermission(id: "perm1", sessionID: "s1", permission: "bash"),
          ],
        );

        final summary = tracker.buildSummary();
        expect(summary.first.activeSessions.first.awaitingInput, isTrue);
      });
    });

    group("multi-project cold start", () {
      test("populates statuses and worktrees correctly", () async {
        final tracker = await _coldStartedTracker(
          projects: [
            const Project(id: "p1", worktree: "/repo-a"),
            const Project(id: "p2", worktree: "/repo-b"),
          ],
          sessions: [
            _session("session-a", "/repo-a"),
            _session("session-b", "/repo-b"),
          ],
          statuses: {
            "session-a": const SessionStatus.busy(),
            "session-b": const SessionStatus.busy(),
          },
        );

        final active = tracker.getActiveStatuses();
        expect(active, hasLength(2));
        expect(active["session-a"], isA<SessionStatusBusy>());
        expect(active["session-b"], isA<SessionStatusBusy>());

        expect(
          tracker.activeSessions,
          equals({"/repo-a": 1, "/repo-b": 1}),
        );

        final summary = tracker.buildSummary();
        expect(summary, hasLength(2));
      });

      test("per-directory error does not break other directories", () async {
        final tracker = await _coldStartedTracker(
          projects: [
            const Project(id: "p1", worktree: "/repo-a"),
            const Project(id: "p2", worktree: "/repo-b"),
          ],
          sessions: [
            _session("session-b", "/repo-b"),
          ],
          statuses: {
            "session-b": const SessionStatus.busy(),
          },
        );

        final active = tracker.getActiveStatuses();
        expect(active, hasLength(1));
        expect(active["session-b"], isA<SessionStatusBusy>());

        final summary = tracker.buildSummary();
        expect(summary, hasLength(1));
        expect(summary.first.id, equals("/repo-b"));
      });
    });

    group("updateProjectWorktrees", () {
      test("resolves pending sessions", () async {
        final tracker = await _coldStartedTracker(projects: []);

        tracker.handleEvent(_sessionCreated("s1", "/repo/sub"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);

        expect(tracker.buildSummary(), isEmpty);

        tracker.updateProjectWorktrees(worktrees: {"/repo"});

        final summary = tracker.buildSummary();
        expect(summary, hasLength(1));
        expect(summary.first.id, equals("/repo"));
      });

      test("replaces old worktrees", () async {
        final tracker = await _coldStartedTracker(
          projects: [const Project(id: "p1", worktree: "/old-repo")],
        );

        tracker.handleEvent(_sessionCreated("s1", "/old-repo/sub"), null);
        tracker.handleEvent(_sessionBusy("s1"), null);
        expect(tracker.buildSummary(), hasLength(1));
        expect(tracker.buildSummary().first.id, equals("/old-repo"));

        tracker.updateProjectWorktrees(worktrees: {"/new-repo"});

        // s1 keeps its resolved worktree mapping from before the update,
        // but new sessions arriving after this will resolve against /new-repo.
        // The worktree set itself is replaced — _projectWorktrees is {/new-repo}.
        expect(tracker.buildSummary(), hasLength(1));
        expect(tracker.buildSummary().first.id, equals("/old-repo"));
      });
    });
  });
}

SseEventData _sessionCreated(String id, String directory) {
  return SseEventData.sessionCreated(
    info: Session(id: id, projectID: "project", directory: directory),
  );
}

SseEventData _childSessionCreated(String id, String parentId, String directory) {
  return SseEventData.sessionCreated(
    info: Session(id: id, projectID: "project", directory: directory, parentID: parentId),
  );
}

SseEventData _sessionUpdated(String id, String directory) {
  return SseEventData.sessionUpdated(
    info: Session(id: id, projectID: "project", directory: directory),
  );
}

SseEventData _sessionDeleted(String id, [String directory = ""]) {
  return SseEventData.sessionDeleted(
    info: Session(id: id, projectID: "project", directory: directory),
  );
}

Session _session(String id, String directory) {
  return Session(id: id, projectID: "project", directory: directory);
}

SseEventData _sessionBusy(String id) {
  return SseEventData.sessionStatus(
    sessionID: id,
    status: const SessionStatus.busy(),
  );
}

SseEventData _sessionIdle(String id) {
  return SseEventData.sessionStatus(
    sessionID: id,
    status: const SessionStatus.idle(),
  );
}

SseEventData _questionAsked(String id, String sessionId) {
  return SseEventData.questionAsked(
    id: id,
    sessionID: sessionId,
    questions: const [],
  );
}

SseEventData _questionReplied(String requestId, String sessionId) {
  return SseEventData.questionReplied(
    requestID: requestId,
    sessionID: sessionId,
  );
}

SseEventData _questionRejected(String requestId, String sessionId) {
  return SseEventData.questionRejected(
    requestID: requestId,
    sessionID: sessionId,
  );
}

SseEventData _permissionAsked(String requestId, String sessionId) {
  return SseEventData.permissionAsked(
    requestID: requestId,
    sessionID: sessionId,
    tool: "test-tool",
    description: "test permission",
  );
}

SseEventData _permissionReplied({required String requestId, required String sessionId}) {
  return SseEventData.permissionReplied(
    requestID: requestId,
    sessionID: sessionId,
    reply: "approve",
  );
}

OpenCodeRepository _fakeRepository({
  List<Project>? projects,
  List<Session>? sessions,
  Map<String, SessionStatus>? statuses,
}) {
  return OpenCodeRepository(
    _FakeApi(
      projects: projects,
      sessions: sessions,
      statuses: statuses,
    ),
  );
}

Future<ActiveSessionTracker> _coldStartedTracker({
  required List<Project> projects,
  List<Session> sessions = const [],
  Map<String, SessionStatus> statuses = const {},
}) async {
  final tracker = ActiveSessionTracker(
    _fakeRepository(
      projects: projects,
      sessions: sessions,
      statuses: statuses,
    ),
  );
  await tracker.coldStart();
  return tracker;
}

class _FakeApi implements OpenCodeApi {
  final List<Project> _projects;
  final List<Session> _sessions;
  final Map<String, SessionStatus> _statuses;

  _FakeApi({
    List<Project>? projects,
    List<Session>? sessions,
    Map<String, SessionStatus>? statuses,
  }) : _projects = projects ?? [],
       _sessions = sessions ?? [],
       _statuses = statuses ?? {};

  @override
  String get serverURL => "http://fake";

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<List<Project>> listProjects() async => _projects;

  @override
  Future<List<Session>> listRootSessions() async => _sessions;

  @override
  Future<List<Session>> listSessions({String? directory, required bool roots}) async => roots ? _sessions.where((s) => s.parentID == null).toList() : _sessions;

  @override
  Future<List<Command>> listCommands({required String? directory}) async => const [];

  @override
  Future<Session> createSession({required String directory, String? parentSessionId}) async =>
      throw UnimplementedError();

  @override
  Future<Session> getSession({required String sessionId, required String? directory}) async =>
      throw UnimplementedError();

  @override
  Future<Session> updateSession({
    required String sessionId,
    required Map<String, dynamic> body,
    required String? directory,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSession({required String sessionId, required String? directory}) async {}

  @override
  Future<void> removeWorktree({
    required String directory,
    required String worktreePath,
  }) async {}

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required SendPromptBody body,
    required String? directory,
  }) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required SendCommandBody body,
    required String? directory,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId, required String? directory}) async {}

  @override
  Future<List<AgentInfo>> listAgents() async => [];

  @override
  Future<List<PendingQuestion>> getPendingQuestions({required String? directory}) async => [];

  @override
  Future<List<PendingPermission>> getPendingPermissions({required String? directory}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required Map<String, dynamic> body,
  }) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId}) async {}

  @override
  Future<Project> getProject({required String directory}) async => throw UnimplementedError();

  @override
  Future<List<Session>> getChildren({
    required String sessionId,
    required String? directory,
  }) async => [];

  @override
  Future<List<MessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
  }) async => [];

  @override
  Future<List<GlobalSession>> listAllSessions({
    required String? directory,
    required bool roots,
  }) async => [];

  @override
  Future<Map<String, SessionStatus>> getSessionStatuses({required String? directory}) async {
    final sessionIdsInDirectory = _sessions
        .where((s) => s.directory == directory || s.directory.startsWith("$directory/"))
        .map((s) => s.id)
        .toSet();
    return Map.fromEntries(
      _statuses.entries.where((e) => sessionIdsInDirectory.contains(e.key)),
    );
  }

  @override
  Future<ProviderListResponse> listProviders() async =>
      const ProviderListResponse(providers: [], defaults: {}, connected: []);

  @override
  Future<ProviderListResponse> listConfigProviders({required String? directory}) async =>
      const ProviderListResponse(providers: [], defaults: {}, connected: []);

  @override
  Future<Project> updateProject({
    required String projectId,
    required String directory,
    required Map<String, dynamic> body,
  }) async => throw UnimplementedError();

  @override
  Future<Session> forkSession({
    required String sessionId,
    required String directory,
  }) async => throw UnimplementedError();
}
