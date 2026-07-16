import "package:injectable/injectable.dart";

import "models/session_activity_info.dart";

@lazySingleton
class SessionActivityCalculator {
  const SessionActivityCalculator();

  bool isRunning({required SessionActivityInfo activity}) {
    return activity.mainAgentRunning || activity.isRetrying || activity.backgroundTaskCount > 0;
  }
}
