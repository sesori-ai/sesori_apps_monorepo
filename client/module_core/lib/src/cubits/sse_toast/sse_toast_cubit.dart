import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "sse_toast_state.dart";

/// Surfaces backend-neutral `tui.toast.show` SSE events (backend notifications
/// and guidance such as a local `/login` hint) as app-wide toast states.
///
/// Every accepted event emits a new [SseToastShow] with a monotonic sequence,
/// so equal repeated guidance is still a distinct effect. Events carrying no
/// renderable text are dropped.
class SseToastCubit(final ConnectionService _connectionService) extends Cubit<SseToastState> {
  late final StreamSubscription<SseEvent> _subscription;
  int _sequence = 0;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  this : super(const SseToastState.idle()) {
    _subscription = _connectionService.events.listen(_handleEvent);
  }

  void _handleEvent(SseEvent event) {
    if (event.data case SesoriTuiToastShow(:final title, :final message, :final variant)) {
      final trimmedTitle = title?.trim();
      final trimmedMessage = message?.trim();
      final text = trimmedMessage == null || trimmedMessage.isEmpty ? trimmedTitle : trimmedMessage;
      if (text == null || text.isEmpty) return;
      if (isClosed) return;
      emit(
        SseToastState.show(
          sequence: ++_sequence,
          title: trimmedMessage == null || trimmedMessage.isEmpty ? null : trimmedTitle,
          message: text,
          variant: SseToastVariant.parse(variant),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
