import "package:bloc/bloc.dart";

import "../../repositories/appearance_store.dart";

/// Holds the app-wide appearance choice.
///
/// Created once at the shell boundary, above the router: the shell resolves its
/// theme from this state while the settings screen writes to it from far below.
/// [initialMode] is the persisted choice, read before the first frame so a
/// pinned theme never flashes the device one.
class AppearanceCubit extends Cubit<AppearanceMode> {
  final AppearanceStore _store;

  AppearanceCubit({required AppearanceStore store, required AppearanceMode initialMode})
    : _store = store,
      super(initialMode);

  /// Switches to [mode] and persists it.
  Future<void> select({required AppearanceMode mode}) async {
    if (mode == state) return;
    emit(mode);
    await _store.write(mode: mode);
  }
}
