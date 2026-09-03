import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/desktop_attention_preference.dart";
import "../../services/desktop_attention_service.dart";

/// Layer-4 presentation owner for the desktop attention preference toggle.
class DesktopAttentionPreferenceCubit({required final DesktopAttentionService service})
    extends Cubit<DesktopAttentionPreference> {
  final DesktopAttentionService _service = service;
  late final StreamSubscription<DesktopAttentionPreference> _subscription;

  this : super(service.currentPreference) {
    _subscription = _service.preference.listen(
      (preference) {
        if (!isClosed && state != preference) {
          emit(preference);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop attention preference stream failed", error, stackTrace);
      },
    );
  }

  Future<void> setEnabled({required bool enabled}) async {
    final preference = enabled ? DesktopAttentionPreference.enabled : DesktopAttentionPreference.disabled;
    try {
      await _service.setPreference(preference: preference);
    } on Object catch (error, stackTrace) {
      logw("Failed to update the desktop attention-notification preference", error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
