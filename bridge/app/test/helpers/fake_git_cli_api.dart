import "dart:io" show ProcessResult;

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";

/// Test fake for [GitCliApi], for tests that wire a repository but never
/// exercise git: every git command fails (non-zero exit), so derived reads
/// resolve to their "absent" results — [getRemoteUrl] returns `null` unless a
/// fixed [remoteUrl] is supplied.
class FakeGitCliApi extends GitCliApi {
  FakeGitCliApi({String? remoteUrl})
    : _remoteUrl = remoteUrl,
      super(processRunner: _FailingProcessRunner(), gitPathExists: _noGitPath);

  final String? _remoteUrl;

  static bool _noGitPath({required String gitPath}) => false;

  @override
  Future<String?> getRemoteUrl({required String projectPath}) async => _remoteUrl;
}

/// Fails every command with exit code 1 without spawning a process.
class _FailingProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(0, 1, "", "FakeGitCliApi: git is unavailable in this test");
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnsupportedError("FakeGitCliApi never starts processes");
  }
}
