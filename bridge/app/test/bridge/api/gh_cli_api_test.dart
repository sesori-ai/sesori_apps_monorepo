import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/api/gh_cli_api.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("GhCliApi.isAvailable", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner.call);
    });

    test("returns true when gh --version exits with code 0", () async {
      processRunner.enqueueResult(result: _ok(stdout: "gh version 2.0.0\n"));

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(processRunner.invocations.first.arguments, equals(["--version"]));
      expect(processRunner.invocations.first.workingDirectory, isNull);
    });

    test("returns false on non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isFalse);
    });

    test("returns false on timeout", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isFalse);
    });

    test("returns false on ProcessException", () async {
      processRunner.enqueueError(
        error: const ProcessException("gh", <String>["--version"], "boom", 1),
      );

      final isAvailable = await service.isAvailable();

      expect(isAvailable, isFalse);
    });
  });

  group("GhCliApi.isAuthenticated", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner.call);
    });

    test("returns true when gh auth status exits with code 0", () async {
      processRunner.enqueueResult(result: _ok());

      final isAuthenticated = await service.isAuthenticated();

      expect(isAuthenticated, isTrue);
      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(processRunner.invocations.first.arguments, equals(["auth", "status"]));
    });

    test("returns false on non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      final isAuthenticated = await service.isAuthenticated();

      expect(isAuthenticated, isFalse);
    });
  });

  group("GhCliApi.listOpenPrs", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner.call);
    });

    test("returns parsed PR list for valid JSON", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout:
              '[{"number":1,"url":"https://example/pr/1","title":"Add feature","state":"OPEN","headRefName":"feat/one","mergeable":"MERGEABLE","reviewDecision":"APPROVED","statusCheckRollup":"SUCCESS"}]',
        ),
      );

      final prs = await service.listOpenPrs(workingDirectory: "/repo");

      expect(
        prs,
        equals(
          <GhPullRequest>[
            const GhPullRequest(
              number: 1,
              url: "https://example/pr/1",
              title: "Add feature",
              state: PrState.open,
              headRefName: "feat/one",
              mergeable: PrMergeableStatus.mergeable,
              reviewDecision: PrReviewDecision.approved,
              statusCheckRollup: PrCheckStatus.success,
            ),
          ],
        ),
      );

      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(
        processRunner.invocations.first.arguments,
        equals(<String>[
          "pr",
          "list",
          "--state",
          "open",
          "--json",
          "number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup",
          "--limit",
          "100",
        ]),
      );
      expect(processRunner.invocations.first.workingDirectory, equals("/repo"));
    });

    test("returns empty list for empty JSON array", () async {
      processRunner.enqueueResult(result: _ok(stdout: "[]"));

      final prs = await service.listOpenPrs(workingDirectory: "/repo");

      expect(prs, isEmpty);
    });

    test("throws on malformed JSON", () async {
      processRunner.enqueueResult(result: _ok(stdout: "not-json"));

      expect(
        () => service.listOpenPrs(workingDirectory: "/repo"),
        throwsA(isA<FormatException>()),
      );
    });

    test("throws on non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      expect(
        () => service.listOpenPrs(workingDirectory: "/repo"),
        throwsA(isA<Exception>()),
      );
    });

    test("throws on timeout", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      expect(
        () => service.listOpenPrs(workingDirectory: "/repo"),
        throwsA(isA<TimeoutException>()),
      );
    });

    test("throws on ProcessException", () async {
      processRunner.enqueueError(
        error: const ProcessException("gh", <String>["pr", "list"], "boom", 1),
      );

      expect(
        () => service.listOpenPrs(workingDirectory: "/repo"),
        throwsA(isA<ProcessException>()),
      );
    });

    test("extracts statusCheckRollup state from object", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout:
              '[{"number":1,"url":"https://example/pr/1","title":"Add feature","state":"OPEN","headRefName":"feat/one","mergeable":"MERGEABLE","reviewDecision":"APPROVED","statusCheckRollup":{"state":"SUCCESS","contexts":[]}}]',
        ),
      );

      final prs = await service.listOpenPrs(workingDirectory: "/repo");

      expect(prs, hasLength(1));
      expect(prs.single.statusCheckRollup, equals(PrCheckStatus.success));
    });

    test("returns unknown statusCheckRollup for unsupported rollup shape", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout:
              '[{"number":1,"url":"https://example/pr/1","title":"Add feature","state":"OPEN","headRefName":"feat/one","mergeable":"MERGEABLE","reviewDecision":"APPROVED","statusCheckRollup":["unexpected"]}]',
        ),
      );

      final prs = await service.listOpenPrs(workingDirectory: "/repo");

      expect(prs, hasLength(1));
      expect(prs.single.statusCheckRollup, equals(PrCheckStatus.unknown));
    });
  });

  group("GhCliApi.getPrByNumber", () {
    late _FakeProcessRunner processRunner;
    late GhCliApi service;

    setUp(() {
      processRunner = _FakeProcessRunner();
      service = GhCliApi(processRunner: processRunner.call);
    });

    test("returns parsed PR for valid JSON", () async {
      processRunner.enqueueResult(
        result: _ok(
          stdout:
              '{"number":12,"url":"https://example/pr/12","title":"Fix bug","state":"OPEN","headRefName":"fix/two","mergeable":"CONFLICTING","reviewDecision":null,"statusCheckRollup":null}',
        ),
      );

      final pr = await service.getPrByNumber(number: 12, workingDirectory: "/repo");

      expect(
        pr,
        equals(
          const GhPullRequest(
            number: 12,
            url: "https://example/pr/12",
            title: "Fix bug",
            state: PrState.open,
            headRefName: "fix/two",
            mergeable: PrMergeableStatus.conflicted,
            reviewDecision: PrReviewDecision.unknown,
            statusCheckRollup: PrCheckStatus.unknown,
          ),
        ),
      );

      expect(processRunner.invocations, hasLength(1));
      expect(processRunner.invocations.first.command, equals("gh"));
      expect(
        processRunner.invocations.first.arguments,
        equals(<String>[
          "pr",
          "view",
          "12",
          "--json",
          "number,url,title,state,headRefName,isCrossRepository,mergeable,reviewDecision,statusCheckRollup",
        ]),
      );
      expect(processRunner.invocations.first.workingDirectory, equals("/repo"));
    });

    test("throws for malformed JSON", () async {
      processRunner.enqueueResult(result: _ok(stdout: "{"));

      expect(
        () => service.getPrByNumber(number: 1, workingDirectory: "/repo"),
        throwsA(isA<FormatException>()),
      );
    });

    test("throws for non-zero exit code", () async {
      processRunner.enqueueResult(result: _fail(exitCode: 1));

      expect(
        () => service.getPrByNumber(number: 1, workingDirectory: "/repo"),
        throwsA(isA<Exception>()),
      );
    });

    test("throws on timeout", () async {
      processRunner.enqueueError(error: TimeoutException("timed out"));

      expect(
        () => service.getPrByNumber(number: 1, workingDirectory: "/repo"),
        throwsA(isA<TimeoutException>()),
      );
    });

    test("throws on ProcessException", () async {
      processRunner.enqueueError(
        error: const ProcessException("gh", <String>["pr", "view", "1"], "boom", 1),
      );

      expect(
        () => service.getPrByNumber(number: 1, workingDirectory: "/repo"),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}

ProcessResult _ok({String stdout = "", String stderr = ""}) {
  return ProcessResult(1, 0, stdout, stderr);
}

ProcessResult _fail({required int exitCode, String stderr = ""}) {
  return ProcessResult(1, exitCode, "", stderr);
}

class _Invocation {
  final String command;
  final List<String> arguments;
  final String? workingDirectory;

  const _Invocation({
    required this.command,
    required this.arguments,
    required this.workingDirectory,
  });
}

class _FakeProcessRunner {
  final List<_Invocation> invocations = <_Invocation>[];
  final List<Object> _queue = <Object>[];

  void enqueueResult({required ProcessResult result}) {
    _queue.add(result);
  }

  void enqueueError({required Object error}) {
    _queue.add(error);
  }

  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    invocations.add(
      _Invocation(
        command: executable,
        arguments: List<String>.from(arguments),
        workingDirectory: workingDirectory,
      ),
    );

    if (_queue.isEmpty) {
      throw StateError("No queued process output for: $executable $arguments");
    }

    final output = _queue.removeAt(0);
    if (output is ProcessResult) {
      return output;
    }
    throw output;
  }
}
