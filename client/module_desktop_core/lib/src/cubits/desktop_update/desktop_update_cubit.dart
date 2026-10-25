import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/desktop_automatic_updates.dart";
import "../../foundation/models/desktop_update_state.dart";
import "../../services/desktop_update_service.dart";

/// What the Settings update rows render.
class const DesktopUpdateSettingsState({
  required final DesktopUpdateState update,
  required final DesktopAutomaticUpdates automaticUpdates,
});

/// Layer-4 presentation owner for the automatic-updates toggle and "Check for updates".
/// "Restart to update" belongs to `BridgeControlCubit`, which owns every exit.
class DesktopUpdateCubit({required final DesktopUpdateService service}) extends Cubit<DesktopUpdateSettingsState> {
  final DesktopUpdateService _service = service;
  late final StreamSubscription<DesktopUpdateState> _updateSubscription;
  late final StreamSubscription<DesktopAutomaticUpdates> _automaticUpdatesSubscription;

  this
    : super(
        DesktopUpdateSettingsState(update: service.currentState, automaticUpdates: service.currentAutomaticUpdates),
      ) {
    _updateSubscription = _service.states.listen(
      (update) => _emit(update: update, automaticUpdates: state.automaticUpdates),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop update state stream failed", error, stackTrace);
      },
    );
    _automaticUpdatesSubscription = _service.automaticUpdates.listen(
      (automaticUpdates) => _emit(update: state.update, automaticUpdates: automaticUpdates),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop automatic-updates preference stream failed", error, stackTrace);
      },
    );
  }

  Future<void> setAutomaticUpdates({required bool enabled}) async {
    try {
      await _service.setAutomaticUpdates(
        preference: enabled ? DesktopAutomaticUpdates.enabled : DesktopAutomaticUpdates.disabled,
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to update the desktop automatic-updates preference", error, stackTrace);
    }
  }

  void checkForUpdates() => _service.check();

  void _emit({required DesktopUpdateState update, required DesktopAutomaticUpdates automaticUpdates}) {
    if (!isClosed) {
      emit(DesktopUpdateSettingsState(update: update, automaticUpdates: automaticUpdates));
    }
  }

  @override
  Future<void> close() async {
    await _automaticUpdatesSubscription.cancel();
    await _updateSubscription.cancel();
    await super.close();
  }
}
