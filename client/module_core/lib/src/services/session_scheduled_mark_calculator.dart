import "package:sesori_shared/sesori_shared.dart";

import "models/session_scheduled_mark.dart";

/// Decides what a session row says about Sesori waking the session again.
/// Owns no state.
class const SessionScheduledMarkCalculator() {
  SessionScheduledMark mark({required Session session}) {
    final task = session.scheduledTask;
    return switch (session.arming) {
      SessionArmingArmed(:final name, :final nextAt) => SessionScheduledMark.armed(name: name, nextAt: nextAt),
      SessionArmingNotArmed() when task != null => SessionScheduledMark.fromTask(name: task.name),
      SessionArmingUnreported() when task != null => SessionScheduledMark.legacyTask(task: task),
      SessionArmingNotArmed() || SessionArmingUnreported() => const SessionScheduledMark.none(),
    };
  }
}
