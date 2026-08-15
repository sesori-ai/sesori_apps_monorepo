import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/worktree_repository.dart";
import "../worktree_types.dart";

export "../worktree_types.dart";

const _maxWorktreeCreationAttempts = 3;
const _suffixSpace = 0x1000000;
const _worktreeDir = ".worktrees";
// Adapted from the MIT-licensed unique-names-generator dictionaries:
// https://github.com/andreasonny83/unique-names-generator/tree/main/src/dictionaries
const _workspaceColors = [
  "amaranth",
  "amber",
  "amethyst",
  "apricot",
  "aqua",
  "aquamarine",
  "azure",
  "beige",
  "black",
  "blue",
  "blush",
  "bronze",
  "brown",
  "chocolate",
  "coffee",
  "copper",
  "coral",
  "crimson",
  "cyan",
  "emerald",
  "fuchsia",
  "gold",
  "gray",
  "green",
  "harlequin",
  "indigo",
  "ivory",
  "jade",
  "lavender",
  "lime",
  "magenta",
  "maroon",
  "moccasin",
  "olive",
  "orange",
  "peach",
  "pink",
  "plum",
  "purple",
  "red",
  "rose",
  "salmon",
  "sapphire",
  "scarlet",
  "silver",
  "tan",
  "teal",
  "tomato",
  "turquoise",
  "violet",
  "white",
  "yellow",
];
const _workspaceAnimals = [
  "aardvark",
  "albatross",
  "alpaca",
  "antelope",
  "armadillo",
  "badger",
  "bandicoot",
  "bear",
  "beaver",
  "bison",
  "bobcat",
  "bonobo",
  "butterfly",
  "camel",
  "capybara",
  "cardinal",
  "caribou",
  "cat",
  "chameleon",
  "cheetah",
  "chickadee",
  "chinchilla",
  "chipmunk",
  "clownfish",
  "condor",
  "cougar",
  "coyote",
  "crane",
  "deer",
  "dingo",
  "dolphin",
  "donkey",
  "dormouse",
  "dove",
  "dragonfly",
  "duck",
  "eagle",
  "echidna",
  "egret",
  "elephant",
  "elk",
  "emu",
  "falcon",
  "ferret",
  "finch",
  "firefly",
  "flamingo",
  "fox",
  "frog",
  "gazelle",
  "gecko",
  "gerbil",
  "gibbon",
  "giraffe",
  "goat",
  "goldfish",
  "goose",
  "gopher",
  "gorilla",
  "guanaco",
  "gull",
  "hamster",
  "hare",
  "hawk",
  "hedgehog",
  "heron",
  "horse",
  "hummingbird",
  "iguana",
  "impala",
  "jaguar",
  "kangaroo",
  "kingfisher",
  "kiwi",
  "koala",
  "lynx",
  "otter",
  "panda",
  "raven",
  "wolf",
];

/// Orchestrates worktree lifecycle for sessions. Callers hand in the stable
/// project IDENTIFIER; this service resolves it to the project's live
/// directory before every git operation (a moved folder keeps its identity
/// but git must run where the folder actually is), while database writes
/// (base-branch override) stay keyed on the identifier.
class WorktreeService({required final WorktreeRepository _worktreeRepository}) {
  static final _random = Random.secure();

  static String _hexSuffix(int value) => value.toRadixString(16).padLeft(6, "0");

  Future<WorktreeResult> prepareWorktreeForSession({
    required String projectId,
    required String? parentSessionId,
  }) async {
    if (parentSessionId != null) {
      final parentWorktree = await _worktreeRepository.getParentWorktree(
        parentSessionId: parentSessionId,
      );
      if (parentWorktree != null) {
        return WorktreeSuccess(
          path: parentWorktree.path,
          branchName: parentWorktree.branchName,
          baseBranch: parentWorktree.baseBranch,
          baseCommit: parentWorktree.baseCommit,
        );
      }
    }

    final projectPath = await _worktreeRepository.resolveProjectPath(projectId: projectId);

    if (!await _worktreeRepository.isGitInitialized(projectPath: projectPath)) {
      Log.w("WorktreeService: not a git repository: $projectPath");
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "not a git repository",
      );
    }

    if (!await _worktreeRepository.hasAtLeastOneCommit(projectPath: projectPath)) {
      Log.w("WorktreeService: repository has no commits: $projectPath");
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "repository has no commits",
      );
    }

    final baseBranchAndCommit = await _worktreeRepository.resolveBaseBranchAndCommit(
      projectId: projectId,
      projectPath: projectPath,
      refreshOrigin: true,
    );
    if (baseBranchAndCommit == null) {
      Log.w(
        "WorktreeService: failed to resolve base branch/commit for: $projectPath",
      );
      return WorktreeFallback(
        originalPath: projectPath,
        reason: "failed to resolve base branch/commit",
      );
    }
    final baseBranch = baseBranchAndCommit.baseBranch;
    final baseCommit = baseBranchAndCommit.baseCommit;
    final startPoint = baseBranchAndCommit.startPoint;

    final colorOffset = _random.nextInt(_workspaceColors.length);
    final animalOffset = _random.nextInt(_workspaceAnimals.length);

    // Advancing both curated lists keeps every bounded candidate distinct.
    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final branchName = _workspaceSlug(
        colorIndex: (colorOffset + attempt) % _workspaceColors.length,
        animalIndex: (animalOffset + attempt) % _workspaceAnimals.length,
      );
      final worktreePath = "$projectPath/$_worktreeDir/$branchName";

      if (await _worktreeRepository.branchExists(
        projectPath: projectPath,
        branchName: branchName,
      )) {
        continue;
      }
      if (_worktreeRepository.worktreePathExists(worktreePath: worktreePath)) {
        continue;
      }

      final created = await _worktreeRepository.createWorktree(
        projectPath: projectPath,
        worktreePath: worktreePath,
        branchName: branchName,
        startPoint: startPoint,
      );

      if (created) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
        );
      }
    }

    final lastSlug = _workspaceSlug(
      colorIndex: (colorOffset + _maxWorktreeCreationAttempts - 1) % _workspaceColors.length,
      animalIndex: (animalOffset + _maxWorktreeCreationAttempts - 1) % _workspaceAnimals.length,
    );
    final suffixOffset = _random.nextInt(_suffixSpace);
    for (var suffixAttempt = 0; suffixAttempt < _maxWorktreeCreationAttempts; suffixAttempt++) {
      final branchName = "$lastSlug-${_hexSuffix((suffixOffset + suffixAttempt) % _suffixSpace)}";
      final worktreePath = "$projectPath/$_worktreeDir/$branchName";
      if (await _worktreeRepository.branchExists(
        projectPath: projectPath,
        branchName: branchName,
      )) {
        continue;
      }
      if (_worktreeRepository.worktreePathExists(worktreePath: worktreePath)) {
        continue;
      }
      final created = await _worktreeRepository.createWorktree(
        projectPath: projectPath,
        worktreePath: worktreePath,
        branchName: branchName,
        startPoint: startPoint,
      );
      if (created) {
        return WorktreeSuccess(
          path: worktreePath,
          branchName: branchName,
          baseBranch: baseBranch,
          baseCommit: baseCommit,
        );
      }
      break;
    }

    Log.w(
      "WorktreeService: failed to create worktree after ${_maxWorktreeCreationAttempts + 1} attempts for: $projectPath",
    );
    return WorktreeFallback(
      originalPath: projectPath,
      reason: "failed to create worktree after ${_maxWorktreeCreationAttempts + 1} attempts",
    );
  }

  static String _workspaceSlug({required int colorIndex, required int animalIndex}) =>
      "${_workspaceColors[colorIndex]}-${_workspaceAnimals[animalIndex]}";

  Future<GeneratedBranchRenameResult> renameGeneratedBranch({
    required String worktreePath,
    required String initialBranchName,
    required String generatedBranchName,
  }) async {
    if (generatedBranchName == initialBranchName) {
      return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.unchanged);
    }
    if (!await _worktreeRepository.isValidBranchName(branchName: generatedBranchName)) {
      return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.invalidGeneratedName);
    }

    final currentBranchName = await _worktreeRepository.getCurrentBranchName(worktreePath: worktreePath);
    if (currentBranchName != initialBranchName) {
      return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.initialBranchChanged);
    }
    if (await _worktreeRepository.hasUpstream(
      worktreePath: worktreePath,
      branchName: initialBranchName,
    )) {
      return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.initialBranchPublished);
    }

    var targetBranchName = generatedBranchName;
    if (await _worktreeRepository.branchExists(
      projectPath: worktreePath,
      branchName: targetBranchName,
    )) {
      final suffixOffset = _random.nextInt(_suffixSpace);
      String? availableBranchName;
      for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
        final candidate = "$generatedBranchName-${_hexSuffix((suffixOffset + attempt) % _suffixSpace)}";
        if (!await _worktreeRepository.isValidBranchName(branchName: candidate)) continue;
        if (!await _worktreeRepository.branchExists(
          projectPath: worktreePath,
          branchName: candidate,
        )) {
          availableBranchName = candidate;
          break;
        }
      }
      if (availableBranchName == null) {
        return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.targetCollisions);
      }
      targetBranchName = availableBranchName;
    }

    await _worktreeRepository.renameBranch(
      worktreePath: worktreePath,
      oldBranchName: initialBranchName,
      newBranchName: targetBranchName,
    );
    final String? confirmedBranchName;
    try {
      confirmedBranchName = await _worktreeRepository.getCurrentBranchName(worktreePath: worktreePath);
    } on Object catch (error, stackTrace) {
      try {
        await rollbackGeneratedBranchRename(
          worktreePath: worktreePath,
          generatedBranchName: targetBranchName,
          initialBranchName: initialBranchName,
        );
      } on Object catch (rollbackError, rollbackStackTrace) {
        Log.w(
          "Could not roll back generated branch after confirmation failed in $worktreePath",
          rollbackError,
          rollbackStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (confirmedBranchName == targetBranchName) {
      return GeneratedBranchRenamed(branchName: targetBranchName);
    }

    await rollbackGeneratedBranchRename(
      worktreePath: worktreePath,
      generatedBranchName: targetBranchName,
      initialBranchName: initialBranchName,
    );
    return GeneratedBranchRenameSkipped(reason: GeneratedBranchRenameSkipReason.initialBranchChanged);
  }

  Future<void> rollbackGeneratedBranchRename({
    required String worktreePath,
    required String generatedBranchName,
    required String initialBranchName,
  }) {
    return _worktreeRepository.renameBranch(
      worktreePath: worktreePath,
      oldBranchName: generatedBranchName,
      newBranchName: initialBranchName,
    );
  }

  Future<String?> resolveHeadCommit({
    required String projectId,
  }) async {
    return await _worktreeRepository.resolveHeadCommit(
      projectPath: await _worktreeRepository.resolveProjectPath(projectId: projectId),
    );
  }

  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
  }) async {
    return await _worktreeRepository.checkWorktreeSafety(
      worktreePath: worktreePath,
    );
  }

  Future<bool> removeWorktree({
    required String pluginId,
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async {
    final projectPath = await _worktreeRepository.resolveProjectPath(projectId: projectId);
    if (!_worktreeRepository.isValidWorktreePath(
      projectPath: projectPath,
      worktreePath: worktreePath,
    )) {
      return false;
    }
    return await _worktreeRepository.removeWorktree(
      pluginId: pluginId,
      projectPath: projectPath,
      worktreePath: worktreePath,
      force: force,
    );
  }

  Future<bool> branchExists({
    required String projectId,
    required String branchName,
  }) async {
    return await _worktreeRepository.branchExists(
      projectPath: await _worktreeRepository.resolveProjectPath(projectId: projectId),
      branchName: branchName,
    );
  }
}
