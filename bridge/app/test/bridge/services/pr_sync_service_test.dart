import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/pr_sync_service.dart";
import "package:test/test.dart";

const _repositoryIdentity = "sesori-ai/sesori_apps_monorepo";
final VerifiedGithubLogin _verifiedGithubLogin = VerifiedGithubLogin.tryParse(rawLogin: "octocat")!;

void main() {
  group("PrSyncService", () {
    test("batches multiple projects through one serialized GitHub selection", () async {
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": _githubTarget(branchName: "feature/one"),
          "/two": _githubTarget(branchName: "feature/two"),
        },
      );
      final pullRequests = _FakePullRequestRepository();
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
          "two": [_session(id: "two", projectId: "two", directory: "/two")],
        },
      );
      addTearDown(service.dispose);

      final outcome = await service.triggerRefresh(
        projectIds: {"one", "two"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );

      expect(outcome, PrRefreshOutcome.completed);
      expect(source.resolveCalls, hasLength(1));
      expect(source.selectionCalls, hasLength(1));
      expect(source.selectionCalls.single.map((target) => target.branchName), ["feature/one", "feature/two"]);
      expect(pullRequests.prepareCalls, hasLength(1));
      expect(pullRequests.prepareCalls.single.projectIds, {"one", "two"});
      expect(pullRequests.prepareCalls.single.githubLogin, "octocat");
      expect(pullRequests.replaceCalls.map((call) => call.projectId).toSet(), {"one", "two"});
      expect(
        pullRequests.replaceCalls.singleWhere((call) => call.projectId == "one").capturedRootDirectories,
        {"one": "/one"},
      );
      expect(source.maxConcurrentSelections, 1);
    });

    test("deduplicates one GitHub target shared by multiple viewed projects", () async {
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": _githubTarget(branchName: "shared-branch"),
          "/two": _githubTarget(branchName: "shared-branch"),
        },
      );
      final pullRequests = _FakePullRequestRepository();
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
          "two": [_session(id: "two", projectId: "two", directory: "/two")],
        },
      );
      addTearDown(service.dispose);

      final outcome = await service.triggerRefresh(
        projectIds: {"one", "two"},
        refreshPolicy: PrRefreshPolicy.viewedProject,
      );

      expect(outcome, PrRefreshOutcome.completed);
      expect(source.selectionCalls, hasLength(1));
      expect(source.selectionCalls.single, hasLength(1));
      expect(pullRequests.replaceCalls.map((call) => call.projectId).toSet(), {"one", "two"});
    });

    test("commits and emits local branch changes before unavailable GitHub work", () async {
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "feature/current")},
      )..isAvailableResult = false;
      final pullRequests = _FakePullRequestRepository()..localChangedProjectIds = {"one"};
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);
      final changes = <String>[];
      final subscription = service.renderedChanges.listen((change) => changes.add(change.projectId));
      addTearDown(subscription.cancel);

      final outcome = await service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );

      expect(outcome, PrRefreshOutcome.failed);
      expect(pullRequests.applyCalls, hasLength(1));
      expect(changes, ["one"]);
      expect(source.selectionCalls, isEmpty);
      expect(pullRequests.prepareCalls, isEmpty);
    });

    test("completes local-only and detached projects without requiring gh", () async {
      final source = _FakePrSource(
        targetsByDirectory: const {
          "/local": PullRequestLocalBranchDirectoryTarget(branchName: "feature/local"),
          "/detached": PullRequestNoBranchDirectoryTarget(
            reason: PullRequestNoBranchReason.detachedHead,
          ),
        },
      )..isAvailableResult = false;
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "local": [_session(id: "local", projectId: "local", directory: "/local")],
          "detached": [_session(id: "detached", projectId: "detached", directory: "/detached")],
        },
      );
      addTearDown(service.dispose);

      final outcome = await service.triggerRefresh(
        projectIds: {"local", "detached"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );

      expect(outcome, PrRefreshOutcome.completed);
      expect(source.isAvailableCallCount, 0);
      expect(source.selectionCalls, isEmpty);
    });

    test("resolves shared root directories once and excludes child directories", () async {
      final source = _FakePrSource(
        targetsByDirectory: const {
          "/shared": PullRequestLocalBranchDirectoryTarget(branchName: "shared"),
        },
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [
            _session(id: "root-a", projectId: "one", directory: "/shared"),
            _session(id: "root-b", projectId: "one", directory: "/shared"),
            _session(
              id: "child",
              projectId: "one",
              directory: "/child",
              parentSessionId: "root-a",
            ),
          ],
        },
      );
      addTearDown(service.dispose);

      expect(
        await service.triggerRefresh(
          projectIds: {"one"},
          refreshPolicy: PrRefreshPolicy.explicit,
        ),
        PrRefreshOutcome.completed,
      );
      expect(source.resolveCalls.single, ["/shared"]);
    });

    test("emits identity-preparation and selected-PR rendered changes", () async {
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "feature/current")},
      );
      final pullRequests = _FakePullRequestRepository()
        ..preparedChangedProjectIds = {"one"}
        ..replacementOutcomes["one"] = const PullRequestReplacementApplied(changed: true);
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);
      final changes = <String>[];
      final subscription = service.renderedChanges.listen((change) => changes.add(change.projectId));
      addTearDown(subscription.cancel);

      expect(
        await service.triggerRefresh(
          projectIds: {"one"},
          refreshPolicy: PrRefreshPolicy.explicit,
        ),
        PrRefreshOutcome.completed,
      );
      expect(changes, ["one", "one"]);
    });

    test("fails a project with a typed local resolution error after applying safe local state", () async {
      final resolutionError = PullRequestTargetResolutionException(
        innerError: StateError("private path must not be rendered"),
        innerStackTrace: StackTrace.current,
      );
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": PullRequestRepositoryResolutionFailed(
            branchName: "feature/current",
            error: resolutionError,
          ),
        },
      );
      final pullRequests = _FakePullRequestRepository()..localChangedProjectIds = {"one"};
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);

      final outcome = await service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );

      expect(outcome, PrRefreshOutcome.failed);
      expect(pullRequests.applyCalls, hasLength(1));
      expect(source.selectionCalls, isEmpty);
      expect(resolutionError.toString(), isNot(contains("private path")));
    });

    test("does not replace rows when the query identity or persisted scope changes", () async {
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "feature/current")},
      )..selectionOutcome = const PullRequestSelectionIdentityChanged();
      final pullRequests = _FakePullRequestRepository();
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);

      expect(
        await service.triggerRefresh(
          projectIds: {"one"},
          refreshPolicy: PrRefreshPolicy.explicit,
        ),
        PrRefreshOutcome.failed,
      );
      expect(pullRequests.replaceCalls, isEmpty);

      source.selectionOutcome = null;
      pullRequests.replacementOutcomes["one"] = const PullRequestReplacementScopeChanged();
      expect(
        await service.triggerRefresh(
          projectIds: {"one"},
          refreshPolicy: PrRefreshPolicy.explicit,
        ),
        PrRefreshOutcome.failed,
      );
      expect(pullRequests.replaceCalls, hasLength(1));
    });

    test("a same-project request after sealing waits for a follow-up generation", () async {
      final firstSelection = Completer<void>();
      final secondSelection = Completer<void>();
      final source = _FakePrSource(
        resolutionResults: [
          {"/one": _githubTarget(branchName: "branch-a")},
          {"/one": _githubTarget(branchName: "branch-b")},
        ],
        selectionBlocks: [firstSelection, secondSelection],
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);

      final first = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      await _waitFor(() => source.selectionCalls.length == 1);
      var secondCompleted = false;
      final second = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      unawaited(second.then((_) => secondCompleted = true));

      firstSelection.complete();
      expect(await first, PrRefreshOutcome.completed);
      await _waitFor(() => source.selectionCalls.length == 2);
      expect(secondCompleted, isFalse);
      expect(source.selectionCalls[0].single.branchName, "branch-a");
      expect(source.selectionCalls[1].single.branchName, "branch-b");
      expect(source.maxConcurrentSelections, 1);

      secondSelection.complete();
      expect(await second, PrRefreshOutcome.completed);
    });

    test("a viewed-project request after sealing gets a serialized covering follow-up", () async {
      final firstSelection = Completer<void>();
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "branch-a")},
        selectionBlocks: [firstSelection],
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);

      final first = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.viewedProject,
      );
      await _waitFor(() => source.selectionCalls.length == 1);
      final followUp = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.viewedProject,
      );
      firstSelection.complete();

      expect(await first, PrRefreshOutcome.completed);
      expect(await followUp, PrRefreshOutcome.completed);
      expect(source.selectionCalls, hasLength(2));
      expect(source.maxConcurrentSelections, 1);
    });

    test("coalesces repeated background requests into an active project refresh", () async {
      final firstSelection = Completer<void>();
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "branch-a")},
        selectionBlocks: [firstSelection],
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );
      addTearDown(service.dispose);

      final first = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      await _waitFor(() => source.selectionCalls.length == 1);
      final backgroundRequests = [
        for (var i = 0; i < 3; i++)
          service.triggerRefresh(
            projectIds: {"one"},
            refreshPolicy: PrRefreshPolicy.background,
          ),
      ];

      firstSelection.complete();

      expect(await first, PrRefreshOutcome.completed);
      expect(await Future.wait(backgroundRequests), everyElement(PrRefreshOutcome.completed));
      expect(source.selectionCalls, hasLength(1));
      expect(source.resolveCalls, hasLength(1));
    });

    test("coalesces pending projects into one immediate follow-up cycle", () async {
      final firstSelection = Completer<void>();
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": _githubTarget(branchName: "one"),
          "/two": _githubTarget(branchName: "two"),
          "/three": _githubTarget(branchName: "three"),
        },
        selectionBlocks: [firstSelection],
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
          "two": [_session(id: "two", projectId: "two", directory: "/two")],
          "three": [_session(id: "three", projectId: "three", directory: "/three")],
        },
      );
      addTearDown(service.dispose);

      final first = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      await _waitFor(() => source.selectionCalls.length == 1);
      final second = service.triggerRefresh(
        projectIds: {"two"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      final third = service.triggerRefresh(
        projectIds: {"three"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      firstSelection.complete();

      await Future.wait([first, second, third]);
      expect(source.selectionCalls, hasLength(2));
      expect(source.selectionCalls[1].map((target) => target.branchName).toSet(), {"two", "three"});
      expect(source.maxConcurrentSelections, 1);
    });

    test("debounces background refreshes, allows bypass, and retries failures", () async {
      var now = DateTime.utc(2026, 8, 2);
      final source = _FakePrSource(
        targetsByDirectory: const {
          "/local": PullRequestLocalBranchDirectoryTarget(branchName: "local"),
        },
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "local": [_session(id: "local", projectId: "local", directory: "/local")],
        },
        clock: Clock(() => now),
        debounceWindow: const Duration(minutes: 1),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      expect(source.resolveCalls, hasLength(1));

      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      expect(source.resolveCalls, hasLength(2));

      now = now.add(const Duration(minutes: 1));
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      expect(source.resolveCalls, hasLength(3));

      source.targetsByDirectory["/local"] = PullRequestBranchResolutionFailed(
        error: PullRequestTargetResolutionException(
          innerError: StateError("failed"),
          innerStackTrace: StackTrace.current,
        ),
      );
      now = now.add(const Duration(minutes: 1));
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      expect(source.resolveCalls, hasLength(5));
    });

    test("viewed-project refresh bypasses the completed background debounce window", () async {
      final source = _FakePrSource(
        targetsByDirectory: const {
          "/local": PullRequestLocalBranchDirectoryTarget(branchName: "local"),
        },
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "local": [_session(id: "local", projectId: "local", directory: "/local")],
        },
        debounceWindow: const Duration(minutes: 1),
      );
      addTearDown(service.dispose);

      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await service.triggerRefresh(
        projectIds: {"local"},
        refreshPolicy: PrRefreshPolicy.viewedProject,
      );

      expect(source.resolveCalls, hasLength(2));
    });

    test("shares and expires a positive gh capability but never caches a negative one", () async {
      var now = DateTime.utc(2026, 8, 2);
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": _githubTarget(branchName: "one"),
          "/two": _githubTarget(branchName: "two"),
        },
      )..isAvailableResult = false;
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
          "two": [_session(id: "two", projectId: "two", directory: "/two")],
        },
        clock: Clock(() => now),
        debounceWindow: Duration.zero,
      );
      addTearDown(service.dispose);

      Future<PrRefreshOutcome> refresh(String projectId) =>
          service.triggerRefresh(projectIds: {projectId}, refreshPolicy: PrRefreshPolicy.explicit);

      await refresh("one");
      await refresh("two");
      expect(source.isAvailableCallCount, 2);
      expect(source.selectionCalls, isEmpty);

      source.isAvailableResult = true;
      await refresh("one");
      now = now.add(const Duration(minutes: 59));
      await refresh("two");
      expect(source.isAvailableCallCount, 3);
      expect(source.selectionCalls, hasLength(2));

      now = now.add(const Duration(minutes: 1));
      await refresh("one");
      expect(source.isAvailableCallCount, 4);
    });

    test("shares and expires a verified identity but never caches a failure", () async {
      var now = DateTime.utc(2026, 8, 2);
      final source = _FakePrSource()..authenticatedIdentity = null;
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: const {},
        clock: Clock(() => now),
      );
      addTearDown(service.dispose);

      expect(await service.verifyGithubIdentity(), isNull);
      expect(await service.verifyGithubIdentity(), isNull);
      expect(source.identityCallCount, 2);

      source.authenticatedIdentity = _verifiedGithubLogin;
      final concurrent = await Future.wait([service.verifyGithubIdentity(), service.verifyGithubIdentity()]);
      expect(concurrent, everyElement(_verifiedGithubLogin));
      expect(source.identityCallCount, 3);

      now = now.add(const Duration(minutes: 59));
      expect(await service.verifyGithubIdentity(), _verifiedGithubLogin);
      expect(source.identityCallCount, 3);

      now = now.add(const Duration(minutes: 1));
      source.authenticatedIdentity = null;
      expect(await service.verifyGithubIdentity(), isNull);
      expect(source.identityCallCount, 4);
    });

    test("skips the identity query when gh is unavailable or unauthenticated", () async {
      final source = _FakePrSource()..isAvailableResult = false;
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: const {},
      );
      addTearDown(service.dispose);

      expect(await service.verifyGithubIdentity(), isNull);
      expect(source.identityCallCount, 0);

      source
        ..isAvailableResult = true
        ..isAuthenticatedResult = false;
      expect(await service.verifyGithubIdentity(), isNull);
      expect(source.identityCallCount, 0);

      source.isAuthenticatedResult = true;
      expect(await service.verifyGithubIdentity(), _verifiedGithubLogin);
      expect(source.identityCallCount, 1);
    });

    test("isolates replacement exceptions and continues later projects", () async {
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": _githubTarget(branchName: "one"),
          "/two": _githubTarget(branchName: "two"),
        },
      );
      final pullRequests = _FakePullRequestRepository()..replacementErrors["one"] = StateError("replacement failed");
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
          "two": [_session(id: "two", projectId: "two", directory: "/two")],
        },
        debounceWindow: const Duration(minutes: 1),
      );
      addTearDown(service.dispose);

      final outcome = await service.triggerRefresh(
        projectIds: {"one", "two"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );

      expect(outcome, PrRefreshOutcome.failed);
      expect(pullRequests.replaceCalls.map((call) => call.projectId), ["one", "two"]);

      await service.triggerRefresh(
        projectIds: {"two"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      expect(pullRequests.replaceCalls, hasLength(2));

      await service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      expect(pullRequests.replaceCalls.map((call) => call.projectId), ["one", "two", "one"]);
    });

    test("dispose fails queued waiters without starting another cycle", () async {
      final selectionBlock = Completer<void>();
      final source = _FakePrSource(
        targetsByDirectory: {"/one": _githubTarget(branchName: "one")},
        selectionBlocks: [selectionBlock],
      );
      final service = _service(
        source: source,
        pullRequests: _FakePullRequestRepository(),
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );

      final first = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      await _waitFor(() => source.selectionCalls.isNotEmpty);
      final queued = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.explicit,
      );
      final disposal = service.dispose();

      expect(await queued, PrRefreshOutcome.failed);
      selectionBlock.complete();
      await disposal;
      expect(await first, PrRefreshOutcome.failed);
      expect(source.selectionCalls, hasLength(1));
    });

    test("dispose during session loading does not start local resolution", () async {
      final sessionLoadBlock = Completer<void>();
      final source = _FakePrSource();
      final pullRequests = _FakePullRequestRepository();
      final sessions = _FakeSessionRepository(
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
        loadBlock: sessionLoadBlock,
      );
      final service = PrSyncService(
        prSource: source,
        pullRequestRepository: pullRequests,
        sessionRepository: sessions,
        clock: const Clock(),
        debounceWindow: Duration.zero,
      );

      final refresh = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await sessions.loadStarted.future;
      final disposal = service.dispose();
      sessionLoadBlock.complete();
      await disposal;
      await _waitFor(() => sessions.completedLoadCount == 1);
      await refresh;

      expect(source.resolveCalls, isEmpty);
      expect(pullRequests.applyCalls, isEmpty);
    });

    test("dispose waits for an active local refresh write", () async {
      final applyBlock = Completer<void>();
      final source = _FakePrSource(
        targetsByDirectory: const {
          "/one": PullRequestLocalBranchDirectoryTarget(branchName: "feature/current"),
        },
      );
      final pullRequests = _FakePullRequestRepository(applyBlock: applyBlock);
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );

      final refresh = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await pullRequests.applyStarted.future;
      final disposal = service.dispose();
      var disposalCompleted = false;
      unawaited(disposal.then((_) => disposalCompleted = true));
      await Future<void>.delayed(Duration.zero);
      expect(disposalCompleted, isFalse);

      applyBlock.complete();
      await disposal;

      expect(disposalCompleted, isTrue);
      expect(await refresh, PrRefreshOutcome.failed);
    });

    test("dispose abandons local resolution finishing during shutdown", () async {
      final resolutionBlock = Completer<void>();
      final resolutionError = PullRequestTargetResolutionException(
        innerError: StateError("git exited during shutdown"),
        innerStackTrace: StackTrace.current,
      );
      final source = _FakePrSource(
        targetsByDirectory: {
          "/one": PullRequestRepositoryResolutionFailed(
            branchName: "feature/current",
            error: resolutionError,
          ),
        },
        resolutionBlock: resolutionBlock,
      );
      final pullRequests = _FakePullRequestRepository();
      final service = _service(
        source: source,
        pullRequests: pullRequests,
        sessionsByProject: {
          "one": [_session(id: "one", projectId: "one", directory: "/one")],
        },
      );

      final refresh = service.triggerRefresh(
        projectIds: {"one"},
        refreshPolicy: PrRefreshPolicy.background,
      );
      await _waitFor(() => source.resolveCalls.isNotEmpty);
      final disposal = service.dispose();
      resolutionBlock.complete();
      await disposal;
      await _waitFor(() => source.completedResolutionCount == 1);
      await refresh;

      expect(pullRequests.applyCalls, isEmpty);
    });
  });
}

PrSyncService _service({
  required _FakePrSource source,
  required _FakePullRequestRepository pullRequests,
  required Map<String, List<StoredSession>> sessionsByProject,
  Clock clock = const Clock(),
  Duration debounceWindow = Duration.zero,
}) {
  return PrSyncService(
    prSource: source,
    pullRequestRepository: pullRequests,
    sessionRepository: _FakeSessionRepository(sessionsByProject: sessionsByProject),
    clock: clock,
    debounceWindow: debounceWindow,
  );
}

PullRequestGithubDirectoryTarget _githubTarget({required String branchName}) {
  return PullRequestGithubDirectoryTarget(
    target: (
      githubRepositoryIdentity: _repositoryIdentity,
      branchName: branchName,
    ),
  );
}

StoredSession _session({
  required String id,
  required String projectId,
  required String directory,
  String? parentSessionId,
}) {
  return StoredSession(
    id: id,
    backendSessionId: id,
    pluginId: "fake",
    projectId: projectId,
    parentSessionId: parentSessionId,
    directory: directory,
    worktreePath: directory,
    branchName: "creation-branch",
    isDedicated: true,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout)) fail("Timed out waiting for condition");
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

final class _FakePrSource({
  Map<String, PullRequestDirectoryTarget> targetsByDirectory = const {},
  final List<Map<String, PullRequestDirectoryTarget>> resolutionResults = const [],
  final List<Completer<void>> selectionBlocks = const [],
  final Completer<void>? resolutionBlock,
}) implements PrSourceRepository {
  final List<List<String>> resolveCalls = <List<String>>[];
  final List<List<PullRequestSelectionTarget>> selectionCalls = <List<PullRequestSelectionTarget>>[];
  Map<String, PullRequestDirectoryTarget> targetsByDirectory = Map<String, PullRequestDirectoryTarget>.from(
    targetsByDirectory,
  );
  PullRequestSelectionOutcome? selectionOutcome;
  bool isAvailableResult = true;
  bool isAuthenticatedResult = true;
  VerifiedGithubLogin? authenticatedIdentity = _verifiedGithubLogin;
  int isAvailableCallCount = 0;
  int isAuthenticatedCallCount = 0;
  int identityCallCount = 0;
  int _activeSelections = 0;
  int maxConcurrentSelections = 0;
  int completedResolutionCount = 0;

  @override
  Future<Map<String, PullRequestDirectoryTarget>> resolvePullRequestTargets({
    required Iterable<String> directories,
  }) async {
    final uniqueDirectories = directories.toSet().toList(growable: false)..sort();
    resolveCalls.add(uniqueDirectories);
    if (resolutionBlock case final block?) await block.future;
    completedResolutionCount++;
    final resultIndex = resolveCalls.length - 1;
    final configured = resultIndex < resolutionResults.length ? resolutionResults[resultIndex] : targetsByDirectory;
    return {
      for (final directory in uniqueDirectories) directory: ?configured[directory],
    };
  }

  @override
  Future<bool> isGithubCliAvailable() async {
    isAvailableCallCount++;
    return isAvailableResult;
  }

  @override
  Future<bool> isGithubCliAuthenticated() async {
    isAuthenticatedCallCount++;
    return isAuthenticatedResult;
  }

  @override
  Future<VerifiedGithubLogin?> getAuthenticatedIdentity() async {
    identityCallCount++;
    return authenticatedIdentity;
  }

  @override
  Future<PullRequestSelectionOutcome> selectPullRequests({
    required List<PullRequestSelectionTarget> targets,
    required VerifiedGithubLogin expectedGithubLogin,
  }) async {
    selectionCalls.add(List<PullRequestSelectionTarget>.from(targets));
    _activeSelections++;
    if (_activeSelections > maxConcurrentSelections) maxConcurrentSelections = _activeSelections;
    try {
      final blockIndex = selectionCalls.length - 1;
      if (blockIndex < selectionBlocks.length) {
        await selectionBlocks[blockIndex].future;
      }
      if (selectionOutcome case final outcome?) return outcome;
      return PullRequestSelectionCompleted(
        selections: [for (final target in targets) PullRequestTargetUnmatched(target: target)],
      );
    } finally {
      _activeSelections--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakePullRequestRepository({final Completer<void>? applyBlock}) implements PullRequestRepository {
  Set<String> localChangedProjectIds = const <String>{};
  Set<String> preparedChangedProjectIds = const <String>{};
  final Map<String, PullRequestReplacementOutcome> replacementOutcomes = <String, PullRequestReplacementOutcome>{};
  final Map<String, Object> replacementErrors = <String, Object>{};
  final List<({Map<String, List<StoredSession>> sessionsByProject, Map<String, PullRequestDirectoryTarget> targets})>
  applyCalls = [];
  final List<({Set<String> projectIds, String githubLogin})> prepareCalls = [];
  final List<
    ({
      String projectId,
      Map<String, String> capturedRootDirectories,
      List<PullRequestTargetSelection> selections,
    })
  >
  replaceCalls = [];
  final Completer<void> applyStarted = Completer<void>();

  @override
  Future<Set<String>> applyResolvedTargets({
    required Map<String, List<StoredSession>> sessionsByProject,
    required Map<String, PullRequestDirectoryTarget> targetsByDirectory,
  }) async {
    applyCalls.add((
      sessionsByProject: Map<String, List<StoredSession>>.from(sessionsByProject),
      targets: Map<String, PullRequestDirectoryTarget>.from(targetsByDirectory),
    ));
    if (!applyStarted.isCompleted) applyStarted.complete();
    if (applyBlock case final block?) await block.future;
    return localChangedProjectIds;
  }

  @override
  Future<Set<String>> prepareScopedRefresh({
    required Set<String> projectIds,
    required VerifiedGithubLogin verifiedGithubLogin,
  }) async {
    prepareCalls.add((projectIds: Set<String>.from(projectIds), githubLogin: verifiedGithubLogin.login));
    return preparedChangedProjectIds;
  }

  @override
  Future<PullRequestReplacementOutcome> replaceScopedPullRequests({
    required String projectId,
    required VerifiedGithubLogin verifiedGithubLogin,
    required Map<String, String> capturedRootDirectoriesBySessionId,
    required List<PullRequestTargetSelection> targetSelections,
    required int lastCheckedAt,
  }) async {
    replaceCalls.add((
      projectId: projectId,
      capturedRootDirectories: Map<String, String>.from(capturedRootDirectoriesBySessionId),
      selections: List<PullRequestTargetSelection>.from(targetSelections),
    ));
    if (replacementErrors[projectId] case final error?) throw error;
    return replacementOutcomes[projectId] ?? const PullRequestReplacementApplied(changed: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeSessionRepository({
  required final Map<String, List<StoredSession>> sessionsByProject,
  final Completer<void>? loadBlock,
}) implements SessionRepository {
  final Completer<void> loadStarted = Completer<void>();
  int completedLoadCount = 0;

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    if (!loadStarted.isCompleted) loadStarted.complete();
    if (loadBlock case final block?) await block.future;
    completedLoadCount++;
    return sessionsByProject[projectId] ?? const <StoredSession>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
