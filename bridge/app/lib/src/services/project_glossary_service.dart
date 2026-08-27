import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock, PendingOperations;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show deriveProjectGlossaryKey;

import "../auth/bridge_id_provider.dart";
import "../foundation/abortable_request.dart";
import "../repositories/project_glossary_repository.dart";
import "../repositories/project_repository.dart";
import "project_glossary_term_calculator.dart";

/// Serializes best-effort glossary population and attempts each requested
/// project at most once during one bridge process.
class ProjectGlossaryService({
  required final BridgeIdProvider _bridgeIdProvider,
  required final ProjectRepository _projectRepository,
  required final ProjectGlossaryRepository _glossaryRepository,
  required final ProjectGlossaryTermCalculator _termCalculator,
}) {
  static const int targetWordCount = ProjectGlossaryTermCalculator.maximumTerms;

  final ParallelLock _lock = ParallelLock(maxParallelOperations: 1);
  final PendingOperations _pendingWork = PendingOperations();
  final AbortSignal _abortSignal = AbortSignal();
  final Set<String> _attemptedProjectKeys = {};
  bool _accepting = true;

  /// Returns this bridge/project pair's opaque key and enqueues population
  /// without blocking the explicit client request.
  ///
  /// Failures are observable in local logs but deliberately do not retry until
  /// the next bridge process. Missing glossary context has low product impact,
  /// while repeated background scans or network attempts would waste resources.
  String? schedule({required String projectId}) {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (!_accepting || bridgeId == null) return null;

    final projectKey = deriveProjectGlossaryKey(bridgeId: bridgeId, projectId: projectId);
    if (_attemptedProjectKeys.add(projectKey)) {
      _pendingWork
          .track(
            operation: _runScheduled(projectId: projectId, projectKey: projectKey),
          )
          .ignore();
    }
    return projectKey;
  }

  void beginShutdown() {
    if (!_accepting) return;
    _accepting = false;
    _abortSignal.abort();
  }

  Future<void> drain() => _pendingWork.drain();

  Future<void> _runScheduled({required String projectId, required String projectKey}) async {
    try {
      await _lock.use(
        operation: () => _populate(projectId: projectId, projectKey: projectKey),
      );
    } on http.RequestAbortedException catch (error, stackTrace) {
      if (!_abortSignal.isAborted) {
        Log.w("Could not populate the project voice glossary for $projectId", error, stackTrace);
      }
    } on Object catch (error, stackTrace) {
      Log.w("Could not populate the project voice glossary for $projectId", error, stackTrace);
    }
  }

  Future<void> _populate({required String projectId, required String projectKey}) async {
    if (_abortSignal.isAborted) return;
    final projectPath = await _projectRepository.resolveProjectDirectory(projectId: projectId);
    final existingWords = await _glossaryRepository.getWords(
      projectKey: projectKey,
      abortSignal: _abortSignal,
    );
    final remainingCapacity = targetWordCount - existingWords.length;
    if (remainingCapacity <= 0 || _abortSignal.isAborted) return;

    final source = await _glossaryRepository.loadSource(projectPath: projectPath);
    if (_abortSignal.isAborted) return;
    final existingFolded = existingWords.map((word) => word.toLowerCase()).toSet();
    final inferredWords = _termCalculator
        .calculate(source: source)
        .where((word) => !existingFolded.contains(word.toLowerCase()))
        .take(remainingCapacity)
        .toList(growable: false);
    if (inferredWords.isEmpty) return;

    await _glossaryRepository.addWords(
      projectKey: projectKey,
      words: inferredWords,
      abortSignal: _abortSignal,
    );
  }
}
