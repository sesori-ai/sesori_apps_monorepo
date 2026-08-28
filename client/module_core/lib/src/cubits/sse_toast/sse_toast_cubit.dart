import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../platform/route_source.dart";
import "../../routing/app_routes.dart";
import "sse_toast_state.dart";

/// Surfaces backend-neutral `tui.toast.show` SSE events (backend notifications
/// and guidance such as a local `/login` hint) as toast states.
///
/// Session-attributed events are accepted only while that session's detail or
/// diffs route is the top route. Unattributed events remain app-wide. Every
/// accepted event emits a new [SseToastShow] with a monotonic sequence, so equal
/// repeated guidance is still a distinct effect. Events carrying no renderable
/// text are dropped.
class SseToastCubit({
  required final ConnectionService _connectionService,
  required final RouteSource _routeSource,
}) extends Cubit<SseToastState> {
  late final StreamSubscription<SseEvent> _subscription;
  int _sequence = 0;

  this : super(const SseToastState.idle()) {
    _subscription = _connectionService.events.listen(_handleEvent);
  }

  void _handleEvent(SseEvent event) {
    if (event.data case SesoriTuiToastShow(:final sessionID, :final title, :final message, :final variant)) {
      if (sessionID != null && !_isShowingSession(sessionId: sessionID)) return;
      final trimmedTitle = title?.trim();
      final trimmedMessage = message?.trim();
      final normalizedTitle = trimmedTitle == null || trimmedTitle.isEmpty ? null : trimmedTitle;
      final text = trimmedMessage == null || trimmedMessage.isEmpty ? normalizedTitle : trimmedMessage;
      if (text == null || text.isEmpty) return;
      if (isClosed) return;
      emit(
        SseToastState.show(
          sequence: ++_sequence,
          title: trimmedMessage == null || trimmedMessage.isEmpty ? null : normalizedTitle,
          message: text,
          variant: SseToastVariant.parse(variant),
        ),
      );
    }
  }

  bool _isShowingSession({required String sessionId}) {
    final route = _routeSource.currentRoute;
    if (route == null || (route != AppRouteDef.sessionDetail && route != AppRouteDef.sessionDiffs)) return false;
    final location = _routeSource.currentLocation;
    final locationSegments = location == null ? null : Uri.tryParse(location)?.pathSegments;
    if (locationSegments == null) return false;
    final sessionIdIndex = Uri.parse(route.path).pathSegments.indexOf(":$sessionIdPathParam");
    return sessionIdIndex >= 0 &&
        sessionIdIndex < locationSegments.length &&
        locationSegments[sessionIdIndex] == sessionId;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
