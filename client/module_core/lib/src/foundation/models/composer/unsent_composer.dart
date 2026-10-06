import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "composer_attachment.dart";
import "composer_draft.dart";

/// What the composing route's composer still held, unsent, when the session it
/// created took over: typed text, a staged command and staged images.
@immutable
final class const UnsentComposer({
  required final ComposerDraft draft,
  required final CommandInfo? command,
  required final List<ComposerAttachment> attachments,
});
