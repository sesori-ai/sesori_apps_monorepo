import "package:injectable/injectable.dart";

import "../../foundation/models/session_launch/session_launch.dart";

/// Process-local storage boundary for in-flight session launches.
@lazySingleton
class SessionLaunchStorage() {
  final Map<String, SessionLaunch> _launches = <String, SessionLaunch>{};

  SessionLaunch? read({required String launchId}) => _launches[launchId];

  Iterable<SessionLaunch> readAll() => _launches.values;

  void write({required SessionLaunch launch}) {
    _launches[launch.launchId] = launch;
  }

  void clear({required String launchId}) => _launches.remove(launchId);
}
