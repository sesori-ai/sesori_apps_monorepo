import "dart:async";

import "package:bloc/bloc.dart";

import "../../services/models/catalog_rescan_state.dart";
import "../../services/session_list_refresh_service.dart";

enum SessionListRefreshStatus() {
  idle,
  refreshing,
  succeeded,
  failed,
}

/// The manual refresh's reload status and the import it started.
final class const SessionListRefreshState({
  required final SessionListRefreshStatus status,
  required final CatalogRescanState scan,
});

/// The manual refresh of the inventories: the session list and Archived pulls
/// and the desktop sidebar's Refresh.
class SessionListRefreshCubit({required final SessionListRefreshService _service})
    extends Cubit<SessionListRefreshState> {
  late final StreamSubscription<CatalogRescanState> _scanSubscription;
  Future<bool>? _inFlight;

  this : super(SessionListRefreshState(status: SessionListRefreshStatus.idle, scan: _service.scan.value)) {
    _scanSubscription = _service.scan
        .skip(1)
        .listen((scan) => emit(SessionListRefreshState(status: state.status, scan: scan)));
  }

  /// Reloads and imports, and reports whether the reload succeeded. A call
  /// while one is running joins it.
  Future<bool> refresh() => _inFlight ??= _refresh();

  Future<bool> _refresh() async {
    emit(SessionListRefreshState(status: SessionListRefreshStatus.refreshing, scan: state.scan));
    final reloaded = await _service.refresh();
    _inFlight = null;
    if (!isClosed) {
      emit(
        SessionListRefreshState(
          status: reloaded ? SessionListRefreshStatus.succeeded : SessionListRefreshStatus.failed,
          scan: state.scan,
        ),
      );
    }
    return reloaded;
  }

  @override
  Future<void> close() async {
    await _scanSubscription.cancel();
    await super.close();
  }
}
