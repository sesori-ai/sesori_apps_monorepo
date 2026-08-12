import "package:bloc/bloc.dart";

import "../../repositories/chat_input_mode_store.dart";

/// Holds the app-wide chat input mode choice.
///
/// Created once at the shell boundary, above the router: the session composer
/// resolves its resting layout from this state while the settings screen
/// writes to it from far below. [initialMode] is the persisted choice, read
/// before the first frame alongside the appearance preference.
class ChatInputModeCubit({required ChatInputModeStore store, required ChatInputMode initialMode}) extends Cubit<ChatInputMode> {
  final ChatInputModeStore _store;

  /// Tail of the persistence chain. Writes append here so rapid re-selection
  /// cannot interleave them and leave an older choice persisted last.
  Future<void> _lastWrite = Future<void>.value();

  this
    : _store = store,
      super(initialMode);

  /// Switches to [mode] and persists it. The app follows the emit
  /// immediately; persistence queues behind any write still in flight.
  Future<void> select({required ChatInputMode mode}) async {
    if (mode == state) return;
    emit(mode);
    _lastWrite = _lastWrite.then((_) => _store.write(mode: mode));
    await _lastWrite;
  }
}
