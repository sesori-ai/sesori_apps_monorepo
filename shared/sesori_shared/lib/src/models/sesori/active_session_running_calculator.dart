import "active_session.dart";

/// Whether an active root session counts as running: its main agent works, it
/// waits to retry, or one of its direct child tasks is active. The bridge and
/// the apps apply this one rule, so a "running" filter agrees on both sides.
class const ActiveSessionRunningCalculator() {
  bool isRunning({required ActiveSession session}) {
    return session.mainAgentRunning || session.isRetrying || session.childSessionIds.isNotEmpty;
  }
}
