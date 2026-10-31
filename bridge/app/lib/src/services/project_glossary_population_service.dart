import "dart:math" show min;

import "package:clock/clock.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey, ProjectGlossaryScope;

import "../repositories/project_glossary_publication_repository.dart";
import "../repositories/project_glossary_repository.dart";
import "project_glossary_term_calculator.dart";

/// Serializes bounded project scans and reconciles their filtered terms into
/// the bridge's exact glossary ownership scope, at most once a day per glossary.
class ProjectGlossaryPopulationService({
  required final ProjectGlossaryRepository _glossaryRepository,
  required final ProjectGlossaryTermCalculator _termCalculator,
  required final ProjectGlossaryPublicationRepository _publicationRepository,
}) {
  // The auth server's per-request word limit. Every desired word is added in
  // one request, so this also caps the glossary size.
  static const int _maximumMutationWords = 100;
  static const Duration _refreshInterval = Duration(hours: 24);
  static const Duration _failureRetryDelay = Duration(minutes: 10);

  final ParallelLock _populationLock = ParallelLock(maxParallelOperations: 1);
  // Keyed by glossary, so worktrees of one repository share a refresh. Set when
  // a refresh is scheduled, which also covers one already queued or running. A
  // bridge restart clears it, which costs one more idempotent refresh.
  final Map<ProjectGlossaryKey, DateTime> _nextRefreshAt = {};
  Future<void>? _disposeFuture;
  bool _accepting = true;

  /// Completes when any refresh this call started has finished. Never throws: a
  /// failed refresh is logged and retried by a later call after a short delay.
  Future<void> refreshIfDue({required ProjectGlossaryScope scope, required String projectPath}) async {
    if (!_accepting) return;

    final now = clock.now();
    final nextRefreshAt = _nextRefreshAt[scope.projectKey];
    if (nextRefreshAt != null && now.isBefore(nextRefreshAt)) return;
    _nextRefreshAt[scope.projectKey] = now.add(_refreshInterval);

    try {
      await _populationLock.use(
        operation: () => _refresh(scope: scope, projectPath: projectPath),
      );
    } on ProjectGlossaryPublicationAbortedException {
      // Expected when bridge shutdown aborts publication transport.
    } on Object catch (error, stackTrace) {
      _nextRefreshAt[scope.projectKey] = clock.now().add(_failureRetryDelay);
      if (!_accepting) return;
      Log.w("Could not refresh the glossary of $projectPath; continuing with the existing one", error, stackTrace);
    }
  }

  Future<void> _refresh({required ProjectGlossaryScope scope, required String projectPath}) async {
    if (!_accepting) return;

    final source = await _glossaryRepository.loadSource(projectPath: projectPath);
    final desiredWords = _termCalculator.calculate(source: source, maximumTerms: _maximumMutationWords);
    if (!_accepting) return;

    final existingWords = await _publicationRepository.getWords(projectKey: scope.projectKey);
    if (!_accepting) return;

    // The read is project-wide and deduplicated across exact owners. Add
    // every desired word idempotently so this scope retains independent
    // ownership even when another scope already contributed the same word.
    if (desiredWords.isNotEmpty) {
      await _publicationRepository.addWords(scope: scope, words: desiredWords);
    }
    if (!_accepting) return;

    final desiredWordSet = desiredWords.toSet();
    final staleWords = existingWords.where((word) => !desiredWordSet.contains(word)).toList(growable: false);
    for (var start = 0; start < staleWords.length; start += _maximumMutationWords) {
      if (!_accepting) return;
      final end = min(start + _maximumMutationWords, staleWords.length);
      await _publicationRepository.removeWords(
        scope: scope,
        words: staleWords.sublist(start, end),
      );
    }
    Log.i("Refreshed the glossary of $projectPath: ${desiredWords.length} words, ${staleWords.length} removed");
  }

  void beginShutdown() {
    if (!_accepting) return;
    _accepting = false;
    _publicationRepository.beginShutdown();
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    beginShutdown();
    await _populationLock.idle;
  }
}
