import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/desktop_automatic_updates.dart";
import "../../foundation/models/desktop_install_kind.dart";
import "../../foundation/models/desktop_update_state.dart";
import "../../services/desktop_update_service.dart";

/// Feedback for "Check for updates" pressed in Settings.
enum DesktopUpdateCheckStatus() {
  idle,
  checking,
  upToDate,
  failed,
}

/// What the Settings update rows render.
class const DesktopUpdateSettingsState({
  required final DesktopUpdateState update,
  required final DesktopAutomaticUpdates automaticUpdates,
  required final DesktopUpdateCheckStatus check,
});

/// Layer-4 presentation owner for the automatic-updates toggle and "Check for updates".
/// "Restart to update" belongs to `BridgeControlCubit`, which owns every exit.
class DesktopUpdateCubit({required final DesktopUpdateService service}) extends Cubit<DesktopUpdateSettingsState> {
  /// How long "You're up to date" or a failed check stays before the row's
  /// usual description returns.
  static const Duration checkResultDuration = Duration(seconds: 4);

  final DesktopUpdateService _service = service;
  Timer? _checkResultTimer;
  late final StreamSubscription<DesktopUpdateState> _updateSubscription;
  late final StreamSubscription<DesktopAutomaticUpdates> _automaticUpdatesSubscription;

  this
    : super(
        DesktopUpdateSettingsState(
          update: service.currentState,
          automaticUpdates: service.currentAutomaticUpdates,
          check: DesktopUpdateCheckStatus.idle,
        ),
      ) {
    _updateSubscription = _service.states.listen(
      (update) => _emit(update: update, automaticUpdates: state.automaticUpdates, check: state.check),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop update state stream failed", error, stackTrace);
      },
    );
    _automaticUpdatesSubscription = _service.automaticUpdates.listen(
      (automaticUpdates) => _emit(update: state.update, automaticUpdates: automaticUpdates, check: state.check),
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

  /// Decides which engine the Settings rows describe; it never changes.
  DesktopInstallKind get installKind => _service.installKind;

  /// Shows the check running, then "You're up to date" or a failure for
  /// [checkResultDuration]. A downloaded update needs no message: its
  /// "Restart to update" row replaces this one.
  Future<void> checkForUpdates() async {
    if (state.check == DesktopUpdateCheckStatus.checking) {
      return;
    }
    _checkResultTimer?.cancel();
    _emitCheck(check: DesktopUpdateCheckStatus.checking);
    final bool finished = await _service.check();
    if (isClosed) {
      return;
    }
    if (_service.currentState is DesktopUpdateReady) {
      _emitCheck(check: DesktopUpdateCheckStatus.idle);
      return;
    }
    _emitCheck(check: finished ? DesktopUpdateCheckStatus.upToDate : DesktopUpdateCheckStatus.failed);
    _checkResultTimer = Timer(checkResultDuration, () => _emitCheck(check: DesktopUpdateCheckStatus.idle));
  }

  void _emitCheck({required DesktopUpdateCheckStatus check}) =>
      _emit(update: state.update, automaticUpdates: state.automaticUpdates, check: check);

  void _emit({
    required DesktopUpdateState update,
    required DesktopAutomaticUpdates automaticUpdates,
    required DesktopUpdateCheckStatus check,
  }) {
    if (!isClosed) {
      emit(DesktopUpdateSettingsState(update: update, automaticUpdates: automaticUpdates, check: check));
    }
  }

  @override
  Future<void> close() async {
    _checkResultTimer?.cancel();
    await _automaticUpdatesSubscription.cancel();
    await _updateSubscription.cancel();
    await super.close();
  }
}
