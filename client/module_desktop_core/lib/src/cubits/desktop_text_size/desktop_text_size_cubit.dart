import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/desktop_text_size.dart";
import "../../foundation/platform/desktop_app_menu.dart";
import "../../repositories/desktop_instance_repository.dart";

/// Holds the window's text size, which Settings, the shortcuts and the app
/// menu all change.
///
/// Created once above the router, like the appearance choice. [initialSize] is
/// the persisted size, read before the first frame so text never jumps to it.
class DesktopTextSizeCubit({
  required final DesktopInstanceRepository _repository,
  required DesktopAppMenu appMenu,
  required DesktopTextSize initialSize,
}) extends Cubit<DesktopTextSize> {
  late final StreamSubscription<DesktopAppMenuCommand> _menuCommands;

  /// Writes run in order, so the size stored last is the size picked last.
  Future<void> _writes = Future<void>.value();

  this : super(initialSize) {
    _menuCommands = appMenu.commands.listen(
      (command) => unawaited(switch (command) {
        DesktopAppMenuCommand.increaseTextSize => increase(),
        DesktopAppMenuCommand.decreaseTextSize => decrease(),
        DesktopAppMenuCommand.resetTextSize => reset(),
      }),
      onError: (Object error, StackTrace stackTrace) {
        loge("Desktop app menu commands failed", error, stackTrace);
      },
    );
  }

  /// Switches to [size] and persists it.
  Future<void> select({required DesktopTextSize size}) {
    if (isClosed || size == state) return _writes;
    emit(size);
    return _writes = _writes.then((_) async {
      try {
        await _repository.writeTextSize(size: size);
      } on Object catch (error, stackTrace) {
        // The window already shows the size; only its persistence is lost.
        logw("Failed to save the desktop text size", error, stackTrace);
      }
    });
  }

  /// One size up; the largest stays as it is.
  Future<void> increase() => select(size: state.bigger);

  /// One size down; the smallest stays as it is.
  Future<void> decrease() => select(size: state.smaller);

  Future<void> reset() => select(size: DesktopTextSize.standard);

  @override
  Future<void> close() async {
    await _menuCommands.cancel();
    await super.close();
    await _writes;
  }
}
