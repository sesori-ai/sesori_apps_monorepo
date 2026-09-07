import "dart:convert" show Utf8Decoder;
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";
import "../foundation/streaming_process_runner.dart";

typedef GitPathExistsChecker = bool Function({required String gitPath});

sealed class const GitCurrentBranchResult();

final class const GitCurrentBranchNamed({required final String branchName}) extends GitCurrentBranchResult;

final class const GitCurrentBranchDetached() extends GitCurrentBranchResult;

final class const GitCurrentBranchMissingDirectory() extends GitCurrentBranchResult;

final class const GitCurrentBranchNotRepository() extends GitCurrentBranchResult;

class GitWorktreeSafetySnapshot({
  required final bool worktreeExists,
  required final bool hasUnstagedChanges,
});

class GitCliApi({
  required final ProcessRunner _processRunner,
  required final StreamingProcessRunner _streamingProcessRunner,
  required final GitPathExistsChecker _gitPathExists,
}) {
  static const Duration _trackedFilesTimeout = Duration(seconds: 15);
  static const List<String> _trackedFilesArguments = ["ls-files", "--cached", "-z", "--", "."];

  Future<bool> isGitInitialized({required String projectPath}) async {
    return _gitPathExists(gitPath: p.join(projectPath, ".git"));
  }

  /// Streams a bounded tracked-file prefix without buffering Git's complete
  /// index output in bridge memory.
  Future<List<String>> listTrackedFiles({required String projectPath, required int maximumPaths}) async {
    if (maximumPaths <= 0) {
      throw ArgumentError.value(maximumPaths, "maximumPaths", "must be positive");
    }

    return await _streamingProcessRunner.run(
      executable: "git",
      arguments: _trackedFilesArguments,
      workingDirectory: projectPath,
      environment: const {"LC_ALL": "C"},
      timeout: _trackedFilesTimeout,
      operation: ({required process}) => _collectTrackedFiles(
        process: process,
        maximumPaths: maximumPaths,
      ),
    );
  }

  Future<bool> isInsideGitWorkTree({required String projectPath}) async {
    const arguments = ["rev-parse", "--is-inside-work-tree"];
    final result = await _processRunner.run(
      "git",
      arguments,
      workingDirectory: projectPath,
      environment: const {"LC_ALL": "C"},
    );
    if (result.exitCode == 0) {
      return result.stdout.toString().trim() == "true";
    }
    if (result.stderr.toString().toLowerCase().contains("not a git repository")) {
      return false;
    }
    throw ProcessException("git", arguments, result.stderr.toString(), result.exitCode);
  }

  Future<GitCurrentBranchResult> getCurrentBranch({required String projectPath}) async {
    if (!_gitPathExists(gitPath: projectPath)) {
      return const GitCurrentBranchMissingDirectory();
    }
    const arguments = ["symbolic-ref", "--quiet", "--short", "HEAD"];
    final ProcessResult result;
    try {
      result = await _processRunner.run(
        "git",
        arguments,
        workingDirectory: projectPath,
        environment: const {"LC_ALL": "C"},
      );
    } on ProcessException {
      if (!_gitPathExists(gitPath: projectPath)) {
        return const GitCurrentBranchMissingDirectory();
      }
      rethrow;
    }
    if (result.exitCode == 0) {
      var branchName = result.stdout.toString();
      if (branchName.endsWith("\r\n")) {
        branchName = branchName.substring(0, branchName.length - 2);
      } else if (branchName.endsWith("\n")) {
        branchName = branchName.substring(0, branchName.length - 1);
      } else if (branchName.endsWith("\r")) {
        branchName = branchName.substring(0, branchName.length - 1);
      }
      if (branchName.isEmpty) {
        throw const FormatException("git returned an empty current branch");
      }
      return GitCurrentBranchNamed(branchName: branchName);
    }

    final stderr = result.stderr.toString();
    if (stderr.toLowerCase().contains("not a git repository")) {
      return const GitCurrentBranchNotRepository();
    }
    if (result.exitCode == 1 && stderr.trim().isEmpty) {
      return const GitCurrentBranchDetached();
    }
    throw ProcessException("git", arguments, stderr, result.exitCode);
  }

  /// Initializes a new git repository at [path]. Returns `true` on success.
  Future<bool> initRepository({required String path}) async {
    final result = await _processRunner.run("git", ["init", path]);
    return result.exitCode == 0;
  }

  /// Stages all changes in [projectPath]. Returns `true` on success.
  Future<bool> stageAll({required String projectPath}) async {
    final result = await runGit(projectPath: projectPath, arguments: const ["add", "."]);
    return result.exitCode == 0;
  }

  /// Creates a commit with [message] in [projectPath]. Returns `true` on success.
  Future<bool> commitAll({required String projectPath, required String message}) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: [
        "-c",
        "user.name=Sesori",
        "-c",
        "user.email=sesori@localhost",
        "-c",
        "commit.gpgSign=false",
        "commit",
        "-m",
        message,
      ],
    );
    return result.exitCode == 0;
  }

  Future<bool> hasAtLeastOneCommit({required String projectPath}) async {
    final result = await runGit(projectPath: projectPath, arguments: const ["rev-parse", "HEAD"]);
    return result.exitCode == 0;
  }

  Future<String> resolveDefaultBranch({required String projectPath}) async {
    final originHeadResult = await runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "refs/remotes/origin/HEAD"],
    );
    final originHeadBranch = _extractBranchName(
      output: originHeadResult.stdout,
      prefix: "refs/remotes/origin/",
    );
    if (originHeadResult.exitCode == 0 && originHeadBranch != null) {
      return originHeadBranch;
    }

    final localHeadResult = await runGit(
      projectPath: projectPath,
      arguments: const ["symbolic-ref", "HEAD"],
    );
    final localHeadBranch = _extractBranchName(
      output: localHeadResult.stdout,
      prefix: "refs/heads/",
    );
    if (localHeadResult.exitCode == 0 && localHeadBranch != null) {
      return localHeadBranch;
    }

    final configuredDefaultBranchResult = await runGit(
      projectPath: projectPath,
      arguments: const ["config", "init.defaultBranch"],
    );
    final configuredDefaultBranch = configuredDefaultBranchResult.stdout.toString().trim();
    if (configuredDefaultBranchResult.exitCode == 0 && configuredDefaultBranch.isNotEmpty) {
      return configuredDefaultBranch;
    }

    return "main";
  }

  /// URL of the repository's remote in [projectPath], preferring `origin` and
  /// falling back to the first listed remote. Null when the directory is not a
  /// git repository, has no remotes, or the remote has no URL configured.
  /// Unexpected failures from an existing repository remain observable.
  Future<String?> getRemoteUrl({required String projectPath}) async {
    if (!await _isInsideGitWorkTreeForRemote(projectPath: projectPath)) {
      return null;
    }
    const remoteArguments = ["remote"];
    final remotesResult = await runGit(projectPath: projectPath, arguments: remoteArguments);
    if (remotesResult.exitCode != 0) {
      throw ProcessException(
        "git",
        remoteArguments,
        remotesResult.stderr.toString(),
        remotesResult.exitCode,
      );
    }
    final remotes = remotesResult.stdout
        .toString()
        .split("\n")
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (remotes.isEmpty) {
      return null;
    }
    final remote = remotes.contains("origin") ? "origin" : remotes.first;
    final getUrlArguments = ["remote", "get-url", remote];
    final urlResult = await runGit(projectPath: projectPath, arguments: getUrlArguments);
    if (urlResult.exitCode != 0) {
      throw ProcessException(
        "git",
        getUrlArguments,
        urlResult.stderr.toString(),
        urlResult.exitCode,
      );
    }
    final url = urlResult.stdout.toString().trim();
    return url.isEmpty ? null : url;
  }

  Future<bool> _isInsideGitWorkTreeForRemote({required String projectPath}) async {
    try {
      return await isInsideGitWorkTree(projectPath: projectPath);
    } on ProcessException {
      if (!_gitPathExists(gitPath: projectPath)) return false;
      rethrow;
    }
  }

  Future<bool> branchExists({
    required String projectPath,
    required String branchName,
  }) async {
    final arguments = ["branch", "--list", "--", branchName];
    final result = await runGit(projectPath: projectPath, arguments: arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        "git",
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return result.stdout.toString().trim().isNotEmpty;
  }

  Future<bool> isValidBranchName({required String branchName}) async {
    final arguments = ["check-ref-format", "--branch", branchName];
    final result = await runGit(projectPath: ".", arguments: arguments);
    return result.exitCode == 0 && result.stdout.toString().trim() == branchName;
  }

  Future<bool> hasUpstream({
    required String projectPath,
    required String branchName,
  }) async {
    final arguments = ["for-each-ref", "--format=%(upstream)", "refs/heads/$branchName"];
    final result = await runGit(projectPath: projectPath, arguments: arguments);
    if (result.exitCode != 0) {
      throw ProcessException("git", arguments, result.stderr.toString(), result.exitCode);
    }
    return result.stdout.toString().trim().isNotEmpty;
  }

  Future<bool> hasRemoteBranch({
    required String projectPath,
    required String branchName,
  }) async {
    const remoteArguments = ["remote"];
    final remotesResult = await runGit(projectPath: projectPath, arguments: remoteArguments);
    if (remotesResult.exitCode != 0) {
      throw ProcessException("git", remoteArguments, remotesResult.stderr.toString(), remotesResult.exitCode);
    }
    final remoteNames = remotesResult.stdout
        .toString()
        .split("\n")
        .map((remote) => remote.trim())
        .where((remote) => remote.isNotEmpty);
    final matchingRefs = {for (final remote in remoteNames) "refs/remotes/$remote/$branchName"};
    if (matchingRefs.isEmpty) return false;

    const refArguments = ["for-each-ref", "--format=%(refname)", "refs/remotes"];
    final refsResult = await runGit(projectPath: projectPath, arguments: refArguments);
    if (refsResult.exitCode != 0) {
      throw ProcessException("git", refArguments, refsResult.stderr.toString(), refsResult.exitCode);
    }
    return refsResult.stdout.toString().split("\n").map((ref) => ref.trim()).any(matchingRefs.contains);
  }

  Future<void> renameBranch({
    required String projectPath,
    required String oldBranchName,
    required String newBranchName,
  }) async {
    final arguments = ["branch", "-m", "--", oldBranchName, newBranchName];
    final result = await runGit(projectPath: projectPath, arguments: arguments);
    if (result.exitCode != 0) {
      throw ProcessException("git", arguments, result.stderr.toString(), result.exitCode);
    }
  }

  Future<bool> createWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String startPoint,
  }) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: ["worktree", "add", "-b", branchName, "--no-track", "--", worktreePath, startPoint],
    );
    return result.exitCode == 0;
  }

  Future<String?> resolveCommit({required String projectPath, required String ref}) async {
    final result = await runGit(projectPath: projectPath, arguments: ["rev-parse", ref]);
    if (result.exitCode != 0) {
      return null;
    }

    final commit = result.stdout.toString().trim();
    return commit.isEmpty ? null : commit;
  }

  Future<ProcessResult> readHeadCommit({required String projectPath}) {
    return runGit(
      projectPath: projectPath,
      arguments: const ["rev-parse", "--verify", "--quiet", "HEAD^{commit}"],
    );
  }

  Future<void> fetchOriginBranch({
    required String projectPath,
    required String branchName,
  }) async {
    if (branchName.contains("*")) {
      throw ArgumentError.value(branchName, "branchName", "must name one exact branch");
    }
    final arguments = [
      "fetch",
      "--no-write-fetch-head",
      "--no-tags",
      "--no-recurse-submodules",
      "origin",
      "+refs/heads/$branchName:refs/remotes/origin/$branchName",
    ];
    final result = await _processRunner.run(
      "git",
      arguments,
      workingDirectory: projectPath,
      timeout: const Duration(seconds: 30),
      environment: const {"GIT_TERMINAL_PROMPT": "0"},
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        "git",
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }

  Future<ProcessResult> verifyRevision({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", "--verify", revision],
    );
  }

  Future<ProcessResult> findMergeBase({
    required String projectPath,
    required String baseRevision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["merge-base", baseRevision, "HEAD"],
    );
  }

  Future<ProcessResult> diffNameStatus({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: [
        "diff",
        "--no-ext-diff",
        "--no-color",
        "--no-renames",
        "--relative",
        "--name-status",
        "-z",
        revision,
        "--",
        ".",
      ],
    );
  }

  Future<ProcessResult> diffNumstat({
    required String projectPath,
    required String revision,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: [
        "diff",
        "--no-ext-diff",
        "--no-color",
        "--no-renames",
        "--relative",
        "--numstat",
        "-z",
        revision,
        "--",
        ".",
      ],
    );
  }

  Future<ProcessResult> listUntrackedFiles({required String projectPath}) {
    return runGit(
      projectPath: projectPath,
      arguments: const ["ls-files", "--others", "--exclude-standard", "-z", "--", "."],
    );
  }

  Future<ProcessResult> fileSizeAtRevision({
    required String projectPath,
    required String revision,
    required String file,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["cat-file", "-s", "$revision:./$file"],
    );
  }

  Future<ProcessResult> readFileAtRevision({
    required String projectPath,
    required String revision,
    required String file,
  }) {
    return runGit(
      projectPath: projectPath,
      arguments: ["show", "$revision:./$file"],
    );
  }

  Future<({String ref, String commit})> resolveStartPointForBranch({
    required String projectPath,
    required String baseBranch,
    required String localCommit,
  }) async {
    final originRef = "refs/remotes/origin/$baseBranch";
    final originResult = await runGit(
      projectPath: projectPath,
      arguments: ["rev-parse", originRef],
    );
    if (originResult.exitCode != 0) {
      return (ref: baseBranch, commit: localCommit);
    }

    final originCommit = originResult.stdout.toString().trim();
    if (originCommit == localCommit) {
      return (ref: baseBranch, commit: localCommit);
    }

    final mergeBaseResult = await runGit(
      projectPath: projectPath,
      arguments: ["merge-base", "--is-ancestor", originCommit, localCommit],
    );
    if (mergeBaseResult.exitCode == 0) {
      return (ref: baseBranch, commit: localCommit);
    }

    return (ref: originRef, commit: originCommit);
  }

  Future<GitWorktreeSafetySnapshot> inspectWorktreeSafety({required String worktreePath}) async {
    if (!Directory(worktreePath).existsSync()) {
      return GitWorktreeSafetySnapshot(worktreeExists: false, hasUnstagedChanges: false);
    }

    final statusResult = await _processRunner.run(
      "git",
      ["status", "--porcelain"],
      workingDirectory: worktreePath,
    );
    final hasUnstagedChanges = statusResult.stdout.toString().trim().isNotEmpty;

    return GitWorktreeSafetySnapshot(
      worktreeExists: true,
      hasUnstagedChanges: hasUnstagedChanges,
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
      Log.w("[GitCli] failed to detect remote", e);
      return false;
    }
  }

  Future<void> pruneWorktrees({required String projectPath}) async {
    await runGit(projectPath: projectPath, arguments: const ["worktree", "prune"]);
  }

  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    final result = await runGit(
      projectPath: projectPath,
      arguments: ["worktree", "remove", if (force) "--force", "--", worktreePath],
    );
    final removed = result.exitCode == 0;

    // Git worktree remove may leave the directory behind if it contains
    // untracked files or build artifacts. Only clean up when the git command
    // succeeded, to avoid bypassing Git's safety checks (e.g. dirty worktree).
    if (removed) {
      final worktreeDir = Directory(worktreePath);
      if (worktreeDir.existsSync()) {
        try {
          worktreeDir.deleteSync(recursive: true);
        } on FileSystemException catch (e) {
          Log.w("[GitCli] failed to delete worktree directory $worktreePath", e);
        }
      }

      // If the parent .worktrees/ directory is now empty, clean it up too.
      final parentDir = worktreeDir.parent;
      if (parentDir.existsSync() && parentDir.path.split(Platform.pathSeparator).last == ".worktrees") {
        try {
          if (parentDir.listSync().isEmpty) {
            parentDir.deleteSync();
          }
        } on FileSystemException catch (e) {
          Log.w("[GitCli] failed to delete empty .worktrees directory ${parentDir.path}", e);
        }
      }
    }

    return removed;
  }

  Future<List<String>> _collectTrackedFiles({
    required StreamingProcess process,
    required int maximumPaths,
  }) async {
    final paths = <String>[];
    final currentPath = StringBuffer();
    final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).join();

    await for (final chunk in process.stdout.transform(const Utf8Decoder(allowMalformed: true))) {
      if (paths.length == maximumPaths) continue;

      var start = 0;
      while (start < chunk.length) {
        final terminator = chunk.indexOf("\u0000", start);
        if (terminator < 0) {
          currentPath.write(chunk.substring(start));
          break;
        }
        currentPath.write(chunk.substring(start, terminator));
        if (currentPath.isNotEmpty) paths.add(currentPath.toString());
        currentPath.clear();
        start = terminator + 1;
        if (paths.length == maximumPaths) break;
      }
    }

    if (currentPath.isNotEmpty && paths.length < maximumPaths) paths.add(currentPath.toString());
    final exitCode = await process.exitCode;
    final stderr = await stderrFuture;
    if (exitCode != 0) {
      throw ProcessException("git", _trackedFilesArguments, stderr, exitCode);
    }
    return paths;
  }

  Future<ProcessResult> runGit({required String projectPath, required List<String> arguments}) {
    return _processRunner.run("git", arguments, workingDirectory: projectPath);
  }

  String? _extractBranchName({required Object? output, required String prefix}) {
    final trimmedOutput = output.toString().trim();
    if (!trimmedOutput.startsWith(prefix)) {
      return null;
    }
    final branchName = trimmedOutput.substring(prefix.length).trim();
    if (branchName.isEmpty) {
      return null;
    }
    return branchName;
  }
}
