import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/git_diff_output_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_diff_repository.dart";
import "package:test/test.dart";

import "../routing/get_session_diffs_handler_test_helpers.dart";

void main() {
  group("SessionDiffRepository.revisionExists", () {
    late FakeProcessRunner processRunner;
    late SessionDiffRepository repository;

    setUp(() {
      processRunner = FakeProcessRunner();
      repository = SessionDiffRepository(
        gitCliApi: GitCliApi(
          processRunner: processRunner,
          gitPathExists: ({required String gitPath}) => true,
        ),
        outputMapper: const GitDiffOutputMapper(),
      );
    });

    test("returns false only for a conclusively missing revision", () async {
      processRunner.responder = ({required List<String> arguments}) => ProcessResult(0, 1, "", "");

      expect(
        await repository.revisionExists(projectPath: "/repo", revision: "deleted-branch"),
        isFalse,
      );
    });

    test("surfaces unexpected revision lookup failures", () async {
      processRunner.responder = ({required List<String> arguments}) =>
          ProcessResult(0, 128, "", "fatal: repository unavailable");

      await expectLater(
        repository.revisionExists(projectPath: "/repo", revision: "feature"),
        throwsA(isA<SessionDiffRepositoryException>()),
      );
    });
  });
}
