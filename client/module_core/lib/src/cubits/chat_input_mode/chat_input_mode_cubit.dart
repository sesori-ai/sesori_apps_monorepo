import "package:bloc/bloc.dart";

import "../../repositories/chat_input_mode_store.dart";

/// Holds the app-wide chat input mode choice.
///
/// Created once at the shell boundary, above the router: the session composer
/// resolves its resting layout from this state while the settings screen
/// writes to it from far below. [initialMode] is the persisted choice, read
/// before the first frame alongside the appearance preference.
class ChatInputModeCubit extends Cubit<ChatInputMode> {
  final ChatInputModeStore _store;

  ChatInputModeCubit({required ChatInputModeStore store, required ChatInputMode initialMode})
    : _store = store,
      super(initialMode);

  /// Switches to [mode] and persists it.
  Future<void> select({required ChatInputMode mode}) async {
    if (mode == state) return;
    emit(mode);
    await _store.write(mode: mode);
  }
}
