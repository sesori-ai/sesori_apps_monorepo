import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart"
    show ProjectGlossaryKey, ProjectGlossaryScope, ProjectGlossaryWordsRequest;

import "../api/sesori_server_api.dart";
import "../foundation/abortable_request.dart";

class ProjectGlossaryPublicationAbortedException({
  required final Object innerError,
  required final StackTrace innerStackTrace,
}) implements Exception;

/// Owns the cancellable auth-server transport for exact glossary scopes.
class ProjectGlossaryPublicationRepository({required final SesoriServerApi _api}) {
  final AbortSignal _abortSignal = AbortSignal();

  void beginShutdown() => _abortSignal.abort();

  Future<List<String>> getWords({required ProjectGlossaryKey projectKey}) {
    return _mapAbort(
      operation: () async {
        final response = await _api.getProjectGlossary(
          projectKey: projectKey,
          abortSignal: _abortSignal,
        );
        return response.words;
      },
    );
  }

  Future<List<String>> addWords({
    required ProjectGlossaryScope scope,
    required List<String> words,
  }) {
    return _mapAbort(
      operation: () async {
        final response = await _api.addProjectGlossaryWords(
          request: ProjectGlossaryWordsRequest(scope: scope, words: words),
          abortSignal: _abortSignal,
        );
        return response.added;
      },
    );
  }

  Future<int> removeWords({
    required ProjectGlossaryScope scope,
    required List<String> words,
  }) {
    return _mapAbort(
      operation: () async {
        final response = await _api.removeProjectGlossaryWords(
          request: ProjectGlossaryWordsRequest(scope: scope, words: words),
          abortSignal: _abortSignal,
        );
        return response.removed;
      },
    );
  }

  Future<T> _mapAbort<T>({required Future<T> Function() operation}) async {
    try {
      return await operation();
    } on http.RequestAbortedException catch (error, stackTrace) {
      throw ProjectGlossaryPublicationAbortedException(
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }
}
