import "dart:async";
import "dart:collection";
import "dart:io";

import "package:sesori_bridge/src/api/gh_pull_request_batch.dart";
import "package:sesori_bridge/src/bridge/api/gh_authenticated_identity.dart";
import "package:sesori_bridge/src/bridge/api/gh_cli_api.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_selection.dart";
import "package:sesori_bridge/src/repositories/models/pull_request_target.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PrSourceRepository", () {
    test("maps the verified gh identity into repository evidence", () async {
      final repository = _repository(
        ghResults: [_result(stdout: "  OctoCat\n")],
        gitResults: const [],
      );

      final identity = await repository.getAuthenticatedIdentity();

      expect(identity?.login, "octocat");
    });

    test("rejects an empty gh identity", () async {
      final repository = _repository(
        ghResults: [_result(stdout: "  \n")],
        gitResults: const [],
      );

      expect(await repository.getAuthenticatedIdentity(), isNull);
    });

    test("resolves a named branch and canonical GitHub repository target", () async {
      final repository = _repository(
        ghResults: const [],
        gitResults: [
          _result(stdout: "Feature/Current\n"),
          _result(stdout: "true\n"),
          _result(stdout: "origin\n"),
          _result(stdout: "git@GitHub.com:Sesori-AI/Sesori_Apps_Monorepo.git\n"),
          _result(stdout: "Feature/Current\n"),
        ],
      );

      final targets = await repository.resolvePullRequestTargets(
        directories: const ["/repo"],
      );

      final target = targets["/repo"]! as PullRequestGithubDirectoryTarget;
      expect(target.target.githubRepositoryIdentity, "sesori-ai/sesori_apps_monorepo");
      expect(target.target.branchName, "Feature/Current");
    });

    test("keeps named branches without a supported GitHub remote", () async {
      for (final remoteUrl in [
        "https://gitlab.com/sesori-ai/sesori_apps_monorepo.git",
        "https://github.com/sesori-ai/mobile/sesori_apps_monorepo.git",
      ]) {
        final repository = _repository(
          ghResults: const [],
          gitResults: [
            _result(stdout: "feature/current\n"),
            _result(stdout: "true\n"),
            _result(stdout: "origin\n"),
            _result(stdout: "$remoteUrl\n"),
            _result(stdout: "feature/current\n"),
          ],
        );

        final targets = await repository.resolvePullRequestTargets(
          directories: const ["/repo"],
        );
        expect(targets["/repo"], isA<PullRequestLocalBranchDirectoryTarget>(), reason: remoteUrl);
      }
    });

    test("deduplicates exact directories and classifies branch absence", () async {
      final detachedAndPlain = _repository(
        ghResults: const [],
        gitResults: [
          ProcessResult(1, 1, "", ""),
          ProcessResult(2, 128, "", "fatal: not a git repository"),
        ],
      );

      final targets = await detachedAndPlain.resolvePullRequestTargets(
        directories: const ["/plain", "/detached", "/detached"],
      );

      expect(
        (targets["/detached"]! as PullRequestNoBranchDirectoryTarget).reason,
        PullRequestNoBranchReason.detachedHead,
      );
      expect(
        (targets["/plain"]! as PullRequestNoBranchDirectoryTarget).reason,
        PullRequestNoBranchReason.notGitRepository,
      );

      final missing = _repository(
        ghResults: const [],
        gitResults: const [],
        gitPathExists: false,
      );
      final missingTargets = await missing.resolvePullRequestTargets(
        directories: const ["/missing"],
      );
      expect(
        (missingTargets["/missing"]! as PullRequestNoBranchDirectoryTarget).reason,
        PullRequestNoBranchReason.missingDirectory,
      );
    });

    test("bounds concurrent deduplicated directory resolution and preserves sorted output", () async {
      final sortedDirectories = [
        for (var index = 0; index < 9; index++) "/directory-${index.toString().padLeft(2, "0")}",
      ];
      final branchResults = {
        for (final directory in sortedDirectories) directory: Completer<GitCurrentBranchResult>(),
      };
      final gitCli = _CompletingGitCliApi(
        branchResults: branchResults,
      );
      final repository = PrSourceRepository(
        ghCli: _FakeGhCliApi(initialResponses: const []),
        gitCli: gitCli,
      );

      final resolution = repository.resolvePullRequestTargets(
        directories: [...sortedDirectories.reversed, sortedDirectories.last],
      );
      await gitCli.resolutionLimitReached.future;

      expect(gitCli.branchCalls, sortedDirectories.take(8));
      expect(gitCli.nextChunkStarted.isCompleted, isFalse);
      for (final directory in sortedDirectories.take(8)) {
        branchResults[directory]!.complete(const GitCurrentBranchDetached());
      }

      await gitCli.nextChunkStarted.future;
      expect(gitCli.branchCalls, sortedDirectories);
      branchResults[sortedDirectories.last]!.complete(const GitCurrentBranchNotRepository());

      final targets = await resolution;
      expect(targets.keys, sortedDirectories);
      expect(targets, hasLength(9));
      expect(
        (targets[sortedDirectories.last]! as PullRequestNoBranchDirectoryTarget).reason,
        PullRequestNoBranchReason.notGitRepository,
      );
    });

    test("returns a typed branch failure when checkout changes during resolution", () async {
      final gitCli = _BranchChangingGitCliApi();
      final repository = PrSourceRepository(
        ghCli: _FakeGhCliApi(initialResponses: const []),
        gitCli: gitCli,
      );

      final resolution = repository.resolvePullRequestTargets(
        directories: const ["/repo"],
      );
      await gitCli.remoteReadStarted.future;
      gitCli.allowRemoteRead.complete();

      expect((await resolution)["/repo"], isA<PullRequestBranchChangedDuringResolution>());
      expect(gitCli.branchCalls, 2);
    });

    test("retains a named branch when repository resolution fails", () async {
      final repository = _repository(
        ghResults: const [],
        gitResults: [
          _result(stdout: "feature/current\n"),
          ProcessResult(2, 2, "", "unexpected remote failure"),
        ],
      );

      final targets = await repository.resolvePullRequestTargets(
        directories: const ["/repo"],
      );

      final failed = targets["/repo"]! as PullRequestRepositoryResolutionFailed;
      expect(failed.branchName, "feature/current");
      expect(failed.error.innerError, isA<ProcessException>());
      expect(failed.error.toString(), isNot(contains("unexpected remote failure")));
    });

    test("returns a typed failure when the current branch command fails", () async {
      final repository = _repository(
        ghResults: const [],
        gitResults: [ProcessResult(1, 2, "", "unexpected branch failure")],
      );

      final targets = await repository.resolvePullRequestTargets(
        directories: const ["/repo"],
      );

      final failed = targets["/repo"]! as PullRequestBranchResolutionFailed;
      expect(failed.error.innerError, isA<ProcessException>());
      expect(failed.error.toString(), isNot(contains("unexpected branch failure")));
    });

    test("selects newest open by creation time and number before terminal", () async {
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(number: 1, createdAt: DateTime.utc(2026, 8, 1), state: PrState.open),
                  _pullRequest(number: 2, createdAt: DateTime.utc(2026, 8, 1), state: PrState.open),
                ],
              ),
              _page(
                stateGroup: GhPullRequestStateGroup.terminal,
                pullRequests: [
                  _pullRequest(number: 99, createdAt: DateTime.utc(2026, 8, 2), state: PrState.closed),
                ],
              ),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: const [_selectionTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );

      expect(outcome, isA<PullRequestSelectionCompleted>());
      final completed = outcome as PullRequestSelectionCompleted;
      final selected = completed.selections.whereType<PullRequestTargetSelected>().single;
      expect(selected.target, _selectionTarget);
      expect(selected.number, 2);
      expect(ghCli.cursorCalls, isEmpty);
    });

    test("paginates past forks and through an equal-createdAt boundary", () async {
      final createdAt = DateTime.utc(2026, 8, 1);
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(number: 30, createdAt: createdAt, state: PrState.open, isCrossRepository: true),
                ],
                hasNextPage: true,
                endCursor: "open-1",
              ),
              _page(stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
            ],
          ),
        ],
        cursorResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [_pullRequest(number: 4, createdAt: createdAt, state: PrState.open)],
                hasNextPage: true,
                endCursor: "open-2",
              ),
            ],
          ),
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [_pullRequest(number: 5, createdAt: createdAt, state: PrState.open)],
              ),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: const [_selectionTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );

      final completed = outcome as PullRequestSelectionCompleted;
      expect(completed.selections.whereType<PullRequestTargetSelected>().single.number, 5);
      expect(ghCli.cursorCalls.map((requests) => requests.single.cursor), ["open-1", "open-2"]);
    });

    test("accepts a canonical repository identity for a historical target", () async {
      const historicalTarget = (
        githubRepositoryIdentity: "sesori-ai/historical-name",
        branchName: "feature/current",
      );
      const canonicalIdentity = "sesori-ai/current-name";
      final createdAt = DateTime.utc(2026, 8, 1);
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                repositoryIdentity: canonicalIdentity,
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(
                    number: 30,
                    createdAt: createdAt,
                    state: PrState.open,
                    isCrossRepository: true,
                  ),
                ],
                hasNextPage: true,
                endCursor: "open-1",
              ),
              _page(
                repositoryIdentity: canonicalIdentity,
                stateGroup: GhPullRequestStateGroup.terminal,
                pullRequests: const [],
              ),
            ],
          ),
        ],
        cursorResponses: [
          _batchResponse(
            pages: [
              _page(
                repositoryIdentity: canonicalIdentity,
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(
                    number: 40,
                    branch: "feature/other",
                    createdAt: createdAt,
                    state: PrState.open,
                  ),
                  _pullRequest(number: 7, createdAt: createdAt, state: PrState.open),
                ],
              ),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: const [historicalTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );

      final selected = (outcome as PullRequestSelectionCompleted).selections.single as PullRequestTargetSelected;
      expect(selected.target, historicalTarget);
      expect(selected.number, 7);
      final cursorTarget = ghCli.cursorCalls.single.single.target;
      expect(cursorTarget.repositoryOwner, "sesori-ai");
      expect(cursorTarget.repositoryName, "historical-name");
      expect(cursorTarget.branchName, "feature/current");
    });

    test("rejects an empty returned repository identity", () async {
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                repositoryIdentity: "",
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: const [],
              ),
              _page(stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      await expectLater(
        repository.selectPullRequests(
          targets: const [_selectionTarget],
          expectedGithubLogin: _verifiedGithubLogin,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            "message",
            contains("repository identity"),
          ),
        ),
      );
    });

    test("rejects a repeated GraphQL cursor instead of looping", () async {
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: const [],
                hasNextPage: true,
                endCursor: "repeated",
              ),
              _page(stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
            ],
          ),
        ],
        cursorResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: const [],
                hasNextPage: true,
                endCursor: "repeated",
              ),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      await expectLater(
        repository.selectPullRequests(
          targets: const [_selectionTarget],
          expectedGithubLogin: _verifiedGithubLogin,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            "message",
            contains("repeated cursor"),
          ),
        ),
      );
      expect(ghCli.cursorCalls, hasLength(1));
    });

    test("falls back to newest terminal and rejects wrong-branch candidates", () async {
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(
                    number: 8,
                    branch: "different",
                    createdAt: DateTime.utc(2026, 8, 2),
                    state: PrState.open,
                  ),
                ],
              ),
              _page(
                stateGroup: GhPullRequestStateGroup.terminal,
                pullRequests: [
                  _pullRequest(number: 7, createdAt: DateTime.utc(2026, 8, 1), state: PrState.merged),
                ],
              ),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: const [_selectionTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );

      final completed = outcome as PullRequestSelectionCompleted;
      expect(completed.selections.whereType<PullRequestTargetSelected>().single.number, 7);
    });

    test("coalesces cursor follow-ups for different targets", () async {
      const secondTarget = (
        githubRepositoryIdentity: _repositoryIdentity,
        branchName: "feature/second",
      );
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _batchResponse(
            pages: [
              _page(
                requestIndex: 0,
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(
                    number: 1,
                    createdAt: DateTime.utc(2026, 8, 1),
                    state: PrState.open,
                    isCrossRepository: true,
                  ),
                ],
                hasNextPage: true,
                endCursor: "cursor-a",
              ),
              _page(requestIndex: 0, stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
              _page(
                requestIndex: 1,
                stateGroup: GhPullRequestStateGroup.open,
                pullRequests: [
                  _pullRequest(
                    number: 2,
                    branch: "feature/second",
                    createdAt: DateTime.utc(2026, 8, 1),
                    state: PrState.open,
                    isCrossRepository: true,
                  ),
                ],
                hasNextPage: true,
                endCursor: "cursor-b",
              ),
              _page(requestIndex: 1, stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
            ],
          ),
        ],
        cursorResponses: [
          _batchResponse(
            pages: [
              _page(requestIndex: 0, stateGroup: GhPullRequestStateGroup.open, pullRequests: const []),
              _page(requestIndex: 1, stateGroup: GhPullRequestStateGroup.open, pullRequests: const []),
            ],
          ),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: const [_selectionTarget, secondTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );

      expect(
        (outcome as PullRequestSelectionCompleted).selections,
        everyElement(isA<PullRequestTargetUnmatched>()),
      );
      expect(ghCli.cursorCalls, hasLength(1));
      expect(ghCli.cursorCalls.single, hasLength(2));
    });

    test("splits more than twenty targets and fences every query identity", () async {
      final targets = [
        for (var index = 0; index < 21; index++)
          (githubRepositoryIdentity: _repositoryIdentity, branchName: "branch-$index"),
      ];
      final ghCli = _FakeGhCliApi(
        initialResponses: [
          _emptyInitialResponse(targetCount: 20),
          _emptyInitialResponse(targetCount: 1),
        ],
      );
      final repository = _selectionRepository(ghCli: ghCli);

      final outcome = await repository.selectPullRequests(
        targets: targets,
        expectedGithubLogin: _verifiedGithubLogin,
      );

      expect((outcome as PullRequestSelectionCompleted).selections, hasLength(21));
      expect(ghCli.initialCalls.map((call) => call.length), [20, 1]);
      expect(ghCli.identityCalls, 1);

      final changedCli = _FakeGhCliApi(
        initialResponses: [_emptyInitialResponse(targetCount: 1, viewerLogin: "hubot")],
      );
      final changedOutcome = await _selectionRepository(ghCli: changedCli).selectPullRequests(
        targets: const [_selectionTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );
      expect(changedOutcome, isA<PullRequestSelectionIdentityChanged>());
      expect(changedCli.identityCalls, 0);

      final finalChangedCli = _FakeGhCliApi(
        initialResponses: [_emptyInitialResponse(targetCount: 1)],
        finalIdentityLogin: "hubot",
      );
      final finalChangedOutcome = await _selectionRepository(ghCli: finalChangedCli).selectPullRequests(
        targets: const [_selectionTarget],
        expectedGithubLogin: _verifiedGithubLogin,
      );
      expect(finalChangedOutcome, isA<PullRequestSelectionIdentityChanged>());
      expect(finalChangedCli.identityCalls, 1);
    });
  });
}

const _repositoryIdentity = "sesori-ai/sesori_apps_monorepo";
const PullRequestSelectionTarget _selectionTarget = (
  githubRepositoryIdentity: _repositoryIdentity,
  branchName: "feature/current",
);
final VerifiedGithubLogin _verifiedGithubLogin = VerifiedGithubLogin.tryParse(rawLogin: "octocat")!;

PrSourceRepository _selectionRepository({required GhCliApi ghCli}) {
  return PrSourceRepository(
    ghCli: ghCli,
    gitCli: GitCliApi(
      processRunner: _QueueProcessRunner(results: const []),
      gitPathExists: ({required String gitPath}) => true,
    ),
  );
}

GhPullRequestBatchResponse _emptyInitialResponse({
  required int targetCount,
  String viewerLogin = "octocat",
}) {
  return _batchResponse(
    viewerLogin: viewerLogin,
    pages: [
      for (var index = 0; index < targetCount; index++) ...[
        _page(requestIndex: index, stateGroup: GhPullRequestStateGroup.open, pullRequests: const []),
        _page(requestIndex: index, stateGroup: GhPullRequestStateGroup.terminal, pullRequests: const []),
      ],
    ],
  );
}

GhPullRequestBatchResponse _batchResponse({
  String viewerLogin = "octocat",
  required List<GhPullRequestCandidatePage> pages,
}) {
  return GhPullRequestBatchResponse(
    errorCount: 0,
    viewerLogin: viewerLogin,
    pages: pages,
  );
}

GhPullRequestCandidatePage _page({
  int requestIndex = 0,
  String repositoryIdentity = _repositoryIdentity,
  required GhPullRequestStateGroup stateGroup,
  required List<GhPullRequest> pullRequests,
  bool hasNextPage = false,
  String? endCursor,
}) {
  return GhPullRequestCandidatePage(
    requestIndex: requestIndex,
    stateGroup: stateGroup,
    repositoryIdentity: repositoryIdentity,
    connection: GhPullRequestConnection(
      nodes: pullRequests,
      pageInfo: GhPullRequestPageInfo(
        hasNextPage: hasNextPage,
        endCursor: endCursor,
      ),
    ),
  );
}

GhPullRequest _pullRequest({
  required int number,
  String branch = "feature/current",
  required DateTime createdAt,
  required PrState state,
  bool isCrossRepository = false,
}) {
  return GhPullRequest(
    number: number,
    url: "https://github.com/$_repositoryIdentity/pull/$number",
    title: "PR $number",
    createdAt: createdAt,
    state: state,
    headRefName: branch,
    isCrossRepository: isCrossRepository,
    mergeable: PrMergeableStatus.mergeable,
    reviewDecision: PrReviewDecision.unknown,
    statusCheckRollup: PrCheckStatus.success,
  );
}

PrSourceRepository _repository({
  required List<ProcessResult> ghResults,
  required List<ProcessResult> gitResults,
  bool gitPathExists = true,
}) {
  return PrSourceRepository(
    ghCli: GhCliApi(processRunner: _QueueProcessRunner(results: ghResults)),
    gitCli: GitCliApi(
      processRunner: _QueueProcessRunner(results: gitResults),
      gitPathExists: ({required String gitPath}) => gitPathExists,
    ),
  );
}

ProcessResult _result({required String stdout}) {
  return ProcessResult(1, 0, stdout, "");
}

final class _FakeGhCliApi({
  required List<GhPullRequestBatchResponse> initialResponses,
  List<GhPullRequestBatchResponse> cursorResponses = const [],
  var String finalIdentityLogin = "octocat",
}) implements GhCliApi {
  final Queue<GhPullRequestBatchResponse> _initialResponses = Queue<GhPullRequestBatchResponse>.from(initialResponses);
  final Queue<GhPullRequestBatchResponse> _cursorResponses = Queue<GhPullRequestBatchResponse>.from(cursorResponses);
  final List<List<GhPullRequestTarget>> initialCalls = <List<GhPullRequestTarget>>[];
  final List<List<GhPullRequestCursorRequest>> cursorCalls = <List<GhPullRequestCursorRequest>>[];
  int identityCalls = 0;

  @override
  Future<GhAuthenticatedIdentity> getAuthenticatedIdentity() async {
    identityCalls++;
    return GhAuthenticatedIdentity(rawLogin: finalIdentityLogin);
  }

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<GhPullRequestBatchResponse> queryInitialPullRequestPages({
    required List<GhPullRequestTarget> targets,
  }) async {
    initialCalls.add(List<GhPullRequestTarget>.from(targets));
    return _initialResponses.removeFirst();
  }

  @override
  Future<GhPullRequestBatchResponse> queryPullRequestCursorPages({
    required List<GhPullRequestCursorRequest> requests,
  }) async {
    cursorCalls.add(List<GhPullRequestCursorRequest>.from(requests));
    return _cursorResponses.removeFirst();
  }
}

class _QueueProcessRunner({required List<ProcessResult> results}) extends ProcessRunner {
  final Queue<ProcessResult> _results = Queue<ProcessResult>.from(results);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_results.isEmpty) {
      throw StateError("Unexpected command: $executable ${arguments.join(" ")}");
    }
    return _results.removeFirst();
  }
}

final class _CompletingGitCliApi({required final Map<String, Completer<GitCurrentBranchResult>> branchResults})
    implements GitCliApi {
  final List<String> branchCalls = <String>[];
  final Completer<void> resolutionLimitReached = Completer<void>();
  final Completer<void> nextChunkStarted = Completer<void>();

  @override
  Future<GitCurrentBranchResult> getCurrentBranch({required String projectPath}) {
    branchCalls.add(projectPath);
    if (branchCalls.length == 8) {
      resolutionLimitReached.complete();
    } else if (branchCalls.length == 9) {
      nextChunkStarted.complete();
    }
    return branchResults[projectPath]!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _BranchChangingGitCliApi() implements GitCliApi {
  final Completer<void> remoteReadStarted = Completer<void>();
  final Completer<void> allowRemoteRead = Completer<void>();
  int branchCalls = 0;

  @override
  Future<GitCurrentBranchResult> getCurrentBranch({required String projectPath}) async {
    branchCalls++;
    return GitCurrentBranchNamed(
      branchName: branchCalls == 1 ? "feature/old" : "feature/new",
    );
  }

  @override
  Future<String?> getRemoteUrl({required String projectPath}) async {
    remoteReadStarted.complete();
    await allowRemoteRead.future;
    return "git@github.com:sesori-ai/sesori_apps_monorepo.git";
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
