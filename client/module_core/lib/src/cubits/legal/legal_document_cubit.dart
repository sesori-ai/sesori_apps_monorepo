import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../repositories/legal_repository.dart";
import "legal_document_state.dart";

/// Loads one legal document's markdown for display.
///
/// The documents are static, so this fetches once on creation; [retry] re-runs
/// the request after a failure.
class LegalDocumentCubit extends Cubit<LegalDocumentState> {
  final LegalRepository _repository;
  final LegalDocument document;

  LegalDocumentCubit({
    required LegalRepository repository,
    required this.document,
  }) : _repository = repository,
       super(const LegalDocumentState.loading()) {
    unawaited(_load());
  }

  /// Re-fetches the document after a failure.
  Future<void> retry() {
    emit(const LegalDocumentState.loading());
    return _load();
  }

  Future<void> _load() async {
    final response = await _repository.getMarkdown(document: document);
    if (isClosed) return;

    switch (response) {
      case SuccessResponse(:final data):
        emit(LegalDocumentState.loaded(markdown: data));
      case ErrorResponse(:final error):
        loge("Failed to load the ${document.name} document", error);
        emit(LegalDocumentState.failed(reason: error.remoteFailureReason));
    }
  }
}
