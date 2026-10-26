import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/models/worktree_types.dart";
import "../repositories/worktree_repository.dart";

export "../repositories/models/worktree_types.dart";

const _maxWorktreeCreationAttempts = 3;
const _suffixSpace = 0x1000000;
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

  Future<WorktreeResult> prepareWorktreeForSession({required String projectId}) async {
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

    Future<_WorktreeCandidateAttempt> attemptCandidate(String slug) => _attemptWorktreeCandidate(
      projectPath: projectPath,
      slug: slug,
      startPoint: startPoint,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
    );

    // Advancing both curated lists keeps every bounded candidate distinct. A
    // failed creation on an available slug moves on to the next slug.
    for (var attempt = 0; attempt < _maxWorktreeCreationAttempts; attempt++) {
      final attempted = await attemptCandidate(
        _workspaceSlug(
          colorIndex: (colorOffset + attempt) % _workspaceColors.length,
          animalIndex: (animalOffset + attempt) % _workspaceAnimals.length,
        ),
      );
      if (attempted case _WorktreeCandidateCreated(:final success)) return success;
    }

    final lastSlug = _workspaceSlug(
      colorIndex: (colorOffset + _maxWorktreeCreationAttempts - 1) % _workspaceColors.length,
      animalIndex: (animalOffset + _maxWorktreeCreationAttempts - 1) % _workspaceAnimals.length,
    );
    // Suffixed candidates skip taken names but stop after one failed creation
    // on an available name: git itself refused, so another suffix will not help.
    final suffixOffset = _random.nextInt(_suffixSpace);
    for (var suffixAttempt = 0; suffixAttempt < _maxWorktreeCreationAttempts; suffixAttempt++) {
      final attempted = await attemptCandidate(
        "$lastSlug-${_hexSuffix((suffixOffset + suffixAttempt) % _suffixSpace)}",
      );
      switch (attempted) {
        case _WorktreeCandidateCreated(:final success):
          return success;
        case _WorktreeCandidateTaken():
          continue;
        case _WorktreeCandidateFailed():
          break;
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

  /// Creates the worktree for [slug] on a detached HEAD unless its path is
  /// taken.
  Future<_WorktreeCandidateAttempt> _attemptWorktreeCandidate({
    required String projectPath,
    required String slug,
    required String startPoint,
    required String baseBranch,
    required String baseCommit,
  }) async {
    final worktreePath = _worktreeRepository.worktreePathFor(projectPath: projectPath, slug: slug);
    if (_worktreeRepository.worktreePathExists(worktreePath: worktreePath)) {
      return const _WorktreeCandidateTaken();
    }
    final created = await _worktreeRepository.createWorktree(
      projectPath: projectPath,
      worktreePath: worktreePath,
      startPoint: startPoint,
    );
    if (!created) return const _WorktreeCandidateFailed();
    return _WorktreeCandidateCreated(
      success: WorktreeSuccess(
        path: worktreePath,
        baseBranch: baseBranch,
        baseCommit: baseCommit,
      ),
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
    required String? baseCommit,
  }) async {
    return await _worktreeRepository.checkWorktreeSafety(
      worktreePath: worktreePath,
      baseCommit: baseCommit,
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
}

/// Outcome of one generated worktree candidate.
sealed class const _WorktreeCandidateAttempt();

/// The path already exists; the candidate was never tried.
final class const _WorktreeCandidateTaken() extends _WorktreeCandidateAttempt;

/// The candidate was available but git refused to create the worktree.
final class const _WorktreeCandidateFailed() extends _WorktreeCandidateAttempt;

final class const _WorktreeCandidateCreated({required final WorktreeSuccess success}) extends _WorktreeCandidateAttempt;
