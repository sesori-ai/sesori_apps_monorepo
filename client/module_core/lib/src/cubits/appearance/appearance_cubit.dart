import "package:bloc/bloc.dart";
import "package:injectable/injectable.dart";

import "../../repositories/appearance_store.dart";

/// Holds the app-wide appearance choice.
///
/// A singleton because the shell resolves its theme from this state above the
/// router, while the settings screen writes to it from far below.
@lazySingleton
class AppearanceCubit extends Cubit<AppearanceMode> {
  final AppearanceStore _store;

  AppearanceCubit({required AppearanceStore store})
    : _store = store,
      super(AppearanceMode.system);

  /// Loads the persisted choice. Awaited during startup so the first frame
  /// already renders in the chosen theme instead of flashing the device one.
  Future<void> restore() async => emit(await _store.read());

  /// Switches to [mode] and persists it.
  Future<void> select({required AppearanceMode mode}) async {
    if (mode == state) return;
    emit(mode);
    await _store.write(mode: mode);
  }
}
