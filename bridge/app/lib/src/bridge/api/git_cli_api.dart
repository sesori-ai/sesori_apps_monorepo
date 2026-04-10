import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

class GitCliApi {
  final ProcessRunner _processRunner;

  GitCliApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

  Future<ProcessResult> fetchRemotes({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["fetch", "--all"],
      workingDirectory: workingDirectory,
      timeout: const Duration(seconds: 30),
    );
  }

  Future<ProcessResult> listBranches({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["branch", "-a", "--sort=-committerdate", "--format=%(refname:short) %(committerdate:unix)"],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> listWorktrees({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["worktree", "list", "--porcelain"],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> addExistingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String branchName,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "--", worktreePath, branchName],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> createTrackingBranchWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String localBranchName,
    required String remoteBranch,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "-b", localBranchName, "--", worktreePath, remoteBranch],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> createWorktree({
    required String workingDirectory,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) {
    return _processRunner.run(
      "git",
      ["worktree", "add", "-b", branchName, "--", worktreePath, startPoint],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> branchExistsLocally({
    required String workingDirectory,
    required String branchName,
  }) {
    return _processRunner.run(
      "git",
      ["branch", "--list", "--", branchName],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> revParse({
    required String workingDirectory,
    required String ref,
  }) {
    return _processRunner.run(
      "git",
      ["rev-parse", ref],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> isAncestor({
    required String workingDirectory,
    required String ancestorRef,
    required String descendantRef,
  }) {
    return _processRunner.run(
      "git",
      ["merge-base", "--is-ancestor", ancestorRef, descendantRef],
      workingDirectory: workingDirectory,
    );
  }

  Future<ProcessResult> getCurrentBranch({required String workingDirectory}) {
    return _processRunner.run(
      "git",
      const ["rev-parse", "--abbrev-ref", "HEAD"],
      workingDirectory: workingDirectory,
    );
  }

  Future<bool> hasGitHubRemote({required String projectPath}) async {
    try {
      final result = await _processRunner.run(
        "git",
        ["config", "--get", "remote.origin.url"],
        workingDirectory: projectPath,
        timeout: const Duration(seconds: 5),
      );

      if (result.exitCode != 0) return false;

      final output = result.stdout.toString().trim();
      return output.isNotEmpty && output.toLowerCase().contains("github.com");
    } on Object catch (e) {
      Log.w("[GitCli] failed to detect remote: $e");
      return false;
    }
  }
}
