import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../foundation/persistence/persistence_keys.dart";
import "../logging/logging.dart";

/// Which input the session composer leads with: press-and-hold voice
/// dictation, or the tap-to-type text field.
enum ChatInputMode({
  /// The persisted spelling of this mode. Pinned here rather than derived from
  /// the enum name so renaming a case cannot orphan a stored preference.
  required final String storageValue,
}) {
  voiceFirst(storageValue: "voice_first"),
  textFirst(storageValue: "text_first");

  /// The mode persisted as [value], or `null` when it matches no known case.
  static ChatInputMode? tryParse({required String value}) {
    for (final mode in ChatInputMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }
}

/// Persists the user's chat input mode choice across app runs.
///
/// The value is an ordinary plaintext preference. It survives logout by
/// design: how the composer leads is a device preference, not account state.
@lazySingleton
class ChatInputModeStore({required final PersisterRepository _persister}) {
  /// The stored chat input preference, or [ChatInputMode.voiceFirst] when
  /// nothing was ever chosen, the stored value is unreadable, or storage
  /// fails. A composer preference is never worth failing startup over.
  Future<ChatInputMode> read() async {
    try {
      final stored = await _persister.readString(key: StringPreferenceKey.chatInputMode);
      if (stored == null) return ChatInputMode.voiceFirst;

      final mode = ChatInputMode.tryParse(value: stored);
      if (mode == null) {
        logw("Ignoring an unknown stored chat input mode: $stored");
        return ChatInputMode.voiceFirst;
      }
      return mode;
    } on Object catch (error, stackTrace) {
      logw("Failed to read the stored chat input mode", error, stackTrace);
      return ChatInputMode.voiceFirst;
    }
  }

  /// Stores [mode] as the chat input preference. A failed write only costs the
  /// choice its persistence — the running app already switched — so it is
  /// logged rather than surfaced.
  Future<void> write({required ChatInputMode mode}) async {
    try {
      await _persister.writeString(key: StringPreferenceKey.chatInputMode, value: mode.storageValue);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the chat input mode", error, stackTrace);
    }
  }
}
