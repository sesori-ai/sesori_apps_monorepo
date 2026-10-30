import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/founder_call/founder_call_sheet_request.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../services/founder_call_service.dart";
import "founder_call_prompt_presentation.dart";

/// Asks the app-root presenter to open the CEO call sheet when
/// [FounderCallService] claims its automatic showing.
class FounderCallPromptCubit({
  required final FounderCallService _founderCallService,
}) extends Cubit<FounderCallPromptPresentation> {
  late final StreamSubscription<FounderCallSheetRequest> _subscription;

  this : super(const FounderCallPromptIdle()) {
    _subscription = _founderCallService.sheetRequests.listen(
      (request) => emit(FounderCallPromptShow(request: request)),
    );
  }

  /// The booking page opened from the sheet.
  void recordLinkOpened() =>
      unawaited(_founderCallService.recordLinkOpened(surface: FounderCallSurface.computerConnectedSheet));

  /// The sheet closed without opening the booking page.
  void recordDeclined() => _founderCallService.recordSheetDeclined();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
