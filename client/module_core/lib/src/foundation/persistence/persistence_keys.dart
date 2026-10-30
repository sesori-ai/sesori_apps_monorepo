import "package:sesori_persistence/sesori_persistence.dart";

enum CoreSecretKey({@override required final String storageKey}) implements SecretStorageKey {
  relayRoomKey(storageKey: "relay_room_key"),
}

enum StringPreferenceKey({@override required final String storageKey}) implements StringPersistenceKey {
  appearanceMode(storageKey: "appearance_mode"),
  chatInputMode(storageKey: "chat_input_mode"),
  feedbackPrompt(storageKey: "feedback_prompt_v1"),
  founderCall(storageKey: "founder_call_v1"),
  notificationPreferencesDeviceId(storageKey: "notification_preferences_device_id_v1"),
  targetBridgeId(storageKey: "target_bridge_id_v1"),
}

enum BoolPreferenceKey({@override required final String storageKey}) implements BoolPersistenceKey {
  hasRegisteredBridges(storageKey: "has_registered_bridges"),
  dedicatedWorktree(storageKey: "new_session_dedicated_worktree_v1"),
}

final class const PluginPreferenceKey({required final String bridgeId}) implements StringPersistenceKey {
  static const prefix = "new_session_plugin_";

  @override
  String get storageKey => "$prefix${Uri.encodeComponent(bridgeId)}";
}

final class const ProductAnalyticsPreferenceKey({required final String userId}) implements StringPersistenceKey {
  static const prefix = "product_analytics_preference_v1:";

  @override
  String get storageKey => "$prefix$userId";
}
