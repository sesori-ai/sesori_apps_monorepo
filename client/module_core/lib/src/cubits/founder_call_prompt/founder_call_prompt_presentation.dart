import "../../foundation/models/founder_call/founder_call_sheet_request.dart";

/// Whether the app-root presenter should open the CEO call sheet by itself.
///
/// Neither variant overrides equality, so every showing is a distinct state.
sealed class const FounderCallPromptPresentation();

final class const FounderCallPromptIdle() extends FounderCallPromptPresentation;

final class const FounderCallPromptShow({required final FounderCallSheetRequest request})
    extends FounderCallPromptPresentation;
