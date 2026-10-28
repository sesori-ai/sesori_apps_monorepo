/// Outcome of opening a file a chat message refers to.
sealed class const FileReferenceOpenOutcome();

/// The file is on this computer and its default app opened it.
final class const FileReferenceOpenedLocally() extends FileReferenceOpenOutcome;

/// The file must be shown in the in-app preview: it is on another computer, or
/// the default app could not open it.
final class const FileReferenceNeedsPreview() extends FileReferenceOpenOutcome;
