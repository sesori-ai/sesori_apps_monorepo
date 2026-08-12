import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";

/// Which input the session composer leads with: press-and-hold voice
/// dictation, or the tap-to-type text field.
enum ChatInputMode {
  voiceFirst(storageValue: "voice_first"),
  textFirst(storageValue: "text_first");

  ChatInputMode({required this.storageValue});

  /// The persisted spelling of this mode. Pinned here rather than derived from
  /// the enum name so renaming a case cannot orphan a stored preference.
  final String storageValue;

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
/// The value is not a secret, but [SecureStorage] is the only key/value store
/// the shells already have, so it carries this preference too rather than
/// pulling in a second storage plugin. It survives logout by design: how the
/// composer leads is a device preference, not account state.
@lazySingleton
class ChatInputModeStore {
  static const _storageKey = "chat_input_mode";

  final SecureStorage _storage;

  ChatInputModeStore({required SecureStorage secureStorage}) : _storage = secureStorage;

  /// The stored chat input preference, or [ChatInputMode.voiceFirst] when
  /// nothing was ever chosen, the stored value is unreadable, or storage
  /// fails. A composer preference is never worth failing startup over.
  Future<ChatInputMode> read() async {
    try {
      final stored = await _storage.read(key: _storageKey);
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
      await _storage.write(key: _storageKey, value: mode.storageValue);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the chat input mode", error, stackTrace);
    }
  }
}
