import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Holds the helper's pending prompts (replace-bridge, login-needed) as
/// stream + snapshot.
///
/// Written by the control-message dispatcher; read by the desktop
/// cubits/window. Prompts are per-connection: a disconnected helper's prompt
/// can never be answered (the bridge resolves it `nonInteractive` on channel
/// loss), so the dispatcher clears the tracker on helper disconnect.
@lazySingleton
class BridgePromptTracker {
  final BehaviorSubject<List<ControlPromptRequest>> _prompts =
      BehaviorSubject.seeded(const <ControlPromptRequest>[]);

  ValueStream<List<ControlPromptRequest>> get promptsStream => _prompts.stream;

  List<ControlPromptRequest> get prompts => _prompts.value;

  /// Records an incoming `prompt_request`; a resend with an id already
  /// pending replaces the original (the helper resends after a reconnect).
  void addPrompt({required ControlPromptRequest prompt}) {
    if (_prompts.isClosed) {
      return;
    }
    _prompts.add([
      for (final ControlPromptRequest pending in prompts)
        if (pending.id != prompt.id) pending,
      prompt,
    ]);
  }

  /// Drops a prompt once it has been answered (or the helper withdrew it).
  void removePrompt({required String id}) {
    if (_prompts.isClosed || !prompts.any((prompt) => prompt.id == id)) {
      return;
    }
    _prompts.add([
      for (final ControlPromptRequest pending in prompts)
        if (pending.id != id) pending,
    ]);
  }

  /// Helper disconnected: pending prompts are unanswerable — drop them all.
  void clear() {
    if (_prompts.isClosed || prompts.isEmpty) {
      return;
    }
    _prompts.add(const <ControlPromptRequest>[]);
  }

  @disposeMethod
  void dispose() {
    _prompts.close();
  }
}
