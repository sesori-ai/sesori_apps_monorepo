import "dart:math" show min;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;

import "../repositories/project_glossary_publication_repository.dart";
import "../repositories/project_glossary_repository.dart";
import "../repositories/project_repository.dart";
import "project_glossary_scope_service.dart";
import "project_glossary_term_calculator.dart";

/// Serializes bounded project scans and reconciles their filtered terms into
/// the bridge's exact glossary ownership scope.
class ProjectGlossaryPopulationService({
  required final ProjectRepository _projectRepository,
  required final ProjectGlossaryScopeService _scopeService,
  required final ProjectGlossaryRepository _glossaryRepository,
  required final ProjectGlossaryTermCalculator _termCalculator,
  required final ProjectGlossaryPublicationRepository _publicationRepository,
}) {
  static const int _maximumMutationWords = 100;

  final ParallelLock _populationLock = ParallelLock(maxParallelOperations: 1);
  Future<void>? _disposeFuture;
  bool _accepting = true;

  Future<void> populate({required String projectId}) {
    if (!_accepting) return Future<void>.value();

    return _populationLock.use(
      operation: () async {
        if (!_accepting) return;

        final project = await _projectRepository.getProject(projectId: projectId);
        if (!_accepting) return;

        final scope = await _scopeService.resolve(projectPath: project.path);
        if (scope == null || !_accepting) return;

        final source = await _glossaryRepository.loadSource(projectPath: project.path);
        final desiredWords = _termCalculator.calculate(source: source);
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
      },
    );
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
