import "package:sesori_shared/sesori_shared.dart";

class SessionLaunchCommand {
  final CommandInfo command;
  final String arguments;

  const SessionLaunchCommand({
    required this.command,
    required this.arguments,
  });
}

class SessionLaunchCommandStore {
  SessionLaunchCommandStore._();

  static final SessionLaunchCommandStore instance = SessionLaunchCommandStore._();

  final Map<String, SessionLaunchCommand> _actions = <String, SessionLaunchCommand>{};

  void save({
    required String sessionId,
    required CommandInfo command,
    required String arguments,
  }) {
    _actions[sessionId] = SessionLaunchCommand(
      command: command,
      arguments: arguments,
    );
  }

  SessionLaunchCommand? take(String sessionId) => _actions.remove(sessionId);

  void clear(String sessionId) {
    _actions.remove(sessionId);
  }
}
