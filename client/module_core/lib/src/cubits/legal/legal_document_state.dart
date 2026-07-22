import "package:freezed_annotation/freezed_annotation.dart";

import "../../errors/api_error_remote_failure_x.dart";

part "legal_document_state.freezed.dart";

@Freezed(fromJson: false, toJson: false)
sealed class LegalDocumentState with _$LegalDocumentState {
  const factory LegalDocumentState.loading() = LegalDocumentLoading;

  const factory LegalDocumentState.loaded({required String markdown}) = LegalDocumentLoaded;

  const factory LegalDocumentState.failed({required RemoteFailureReason reason}) = LegalDocumentFailed;
}
