/// A launch still waiting for its session, as a launching row draws it.
final class const LaunchingSession({
  required final String launchId,
  required final String projectId,
  required final String pluginId,
  required final DateTime startedAt,

  /// The first line of the first message; null for an attachment-only start.
  required final String? title,
});

final class const SessionLaunchState({
  /// The launches still waiting for their session, newest first.
  required final List<LaunchingSession> launching,

  /// The session each launch that has one was created as, by launchId. A
  /// launch leaves this once nothing more is owed for it, so a list drawing
  /// its launching row takes the session from the update that adds it.
  required final Map<String, String> sessionIds,
});
