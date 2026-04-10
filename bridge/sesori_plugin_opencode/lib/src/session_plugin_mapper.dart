import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;

import "active_session_tracker.dart";
import "models/session.dart";

class SessionPluginMapper {
  final ActiveSessionTracker _tracker;

  SessionPluginMapper({required ActiveSessionTracker tracker}) : _tracker = tracker;

  PluginSession toPluginSession({
    required Session session,
    required String fallbackProjectID,
  }) {
    return _canonicalize(
      session: session,
      fallbackProjectID: fallbackProjectID,
    ).toPlugin();
  }

  Map<String, dynamic> toBridgeSessionInfo({
    required Session session,
    required String fallbackProjectID,
  }) {
    return _canonicalize(
      session: session,
      fallbackProjectID: fallbackProjectID,
    ).toJson();
  }

  Session _canonicalize({
    required Session session,
    required String fallbackProjectID,
  }) {
    final projectID = _tracker.resolveProjectWorktree(directory: session.directory) ?? fallbackProjectID;
    return session.copyWith(projectID: projectID);
  }
}
