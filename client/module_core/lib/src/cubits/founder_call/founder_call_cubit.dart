import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/founder_call/founder_call_availability.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../services/founder_call_service.dart";

/// Whether a screen offers the CEO call, and records bookings made from it.
class FounderCallCubit({
  required final FounderCallService _founderCallService,
}) extends Cubit<FounderCallAvailability> {
  this : super(const FounderCallHidden()) {
    unawaited(_load());
  }

  /// The booking page opened from [surface].
  void recordLinkOpened({required FounderCallSurface surface}) =>
      unawaited(_founderCallService.recordLinkOpened(surface: surface));

  Future<void> _load() async {
    final availability = await _founderCallService.readAvailability();
    if (!isClosed) emit(availability);
  }
}
