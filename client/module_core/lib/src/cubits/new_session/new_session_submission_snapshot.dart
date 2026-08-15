import "package:freezed_annotation/freezed_annotation.dart";

import "../../foundation/models/composer/composer_attachment.dart";
import "../../foundation/models/composer/composer_draft.dart";

part "new_session_submission_snapshot.freezed.dart";

@Freezed()
sealed class const NewSessionSubmissionSnapshot._() with _$NewSessionSubmissionSnapshot {
  const factory text({
    required ComposerDraft draft,
    required List<ComposerAttachment> attachments,
  }) = NewSessionTextSubmissionSnapshot;

  const factory command({
    required ComposerDraft draft,
    required String command,
  }) = NewSessionCommandSubmissionSnapshot;
}
