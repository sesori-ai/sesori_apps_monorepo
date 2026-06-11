import "package:meta/meta.dart";

/// Lifecycle status of a started plugin instance.
///
/// Statuses form a state machine with these legal transitions:
///
/// | From         | To                                                       |
/// |--------------|----------------------------------------------------------|
/// | `Starting`   | `Ready`, `Degraded`, `Failed`, `Stopping`                |
/// | `Ready`      | `Degraded`, `Restarting`, `Failed`, `Stopping`           |
/// | `Degraded`   | `Ready`, `Degraded`, `Restarting`, `Failed`, `Stopping`  |
/// | `Restarting` | `Ready`, `Degraded`, `Restarting`, `Failed`, `Stopping`  |
/// | `Failed`     | `Stopping`                                               |
/// | `Stopping`   | `Stopped`                                                |
/// | `Stopped`    | (none — the status stream closes)                        |
///
/// Two rules matter most to the bridge core:
///
/// - **No `Failed` after `Stopping`.** Racy failure sources (exit monitors,
///   health probes) observing a runtime that the plugin itself is tearing down
///   must not turn a clean shutdown into a reported failure. Such sources
///   should publish through `PluginStatusController.trySet`, which silently
///   drops illegal transitions.
/// - **The stream closes after `Stopped`.** `Stopped` is the terminal status;
///   nothing may follow it.
///
/// `Degraded -> Degraded` and `Restarting -> Restarting` are legal so a plugin
/// can refresh details (a new hint, the next restart attempt) without leaving
/// the state. Setting a status equal to the current one is a no-op everywhere.
@immutable
sealed class PluginStatus {
  const PluginStatus();

  /// Whether the state machine permits moving from this status to [next].
  ///
  /// Transitioning to a status equal to the current one is handled by the
  /// publisher as a no-op and is not part of this relation.
  bool canTransitionTo(PluginStatus next) {
    return switch (this) {
      PluginStarting() =>
        next is PluginReady || next is PluginDegraded || next is PluginFailed || next is PluginStopping,
      PluginReady() =>
        next is PluginDegraded || next is PluginRestarting || next is PluginFailed || next is PluginStopping,
      PluginDegraded() || PluginRestarting() =>
        next is PluginReady ||
            next is PluginDegraded ||
            next is PluginRestarting ||
            next is PluginFailed ||
            next is PluginStopping,
      PluginFailed() => next is PluginStopping,
      PluginStopping() => next is PluginStopped,
      PluginStopped() => false,
    };
  }
}

/// The plugin is acquiring its resources; `start()` has not completed yet.
final class PluginStarting extends PluginStatus {
  const PluginStarting();

  @override
  bool operator ==(Object other) => other is PluginStarting;

  @override
  int get hashCode => (PluginStarting).hashCode;

  @override
  String toString() => "PluginStarting";
}

/// The plugin is fully operational.
final class PluginReady extends PluginStatus {
  const PluginReady();

  @override
  bool operator ==(Object other) => other is PluginReady;

  @override
  int get hashCode => (PluginReady).hashCode;

  @override
  String toString() => "PluginReady";
}

/// The plugin is reachable but impaired (backend unreachable, auth expired).
///
/// Degraded is a recoverable observation by default: transient connectivity
/// loss should surface here, not as [PluginFailed]. When recovery needs a
/// human (e.g. a remote plugin's credentials expired), set
/// [requiresUserAction] and explain what to do in [userActionHint].
final class PluginDegraded extends PluginStatus {
  const PluginDegraded({
    required this.since,
    this.recoverable = true,
    this.requiresUserAction = false,
    this.userActionHint,
  });

  /// When the degradation was first observed (not when it was reported —
  /// debounced reporters keep the earliest observation time).
  final DateTime since;

  /// Whether the plugin expects to recover without intervention.
  final bool recoverable;

  /// Whether recovery needs the user to act (re-authenticate, restart a
  /// remote server). When `true`, [userActionHint] should say what to do.
  final bool requiresUserAction;

  /// Human-readable instruction shown when [requiresUserAction] is `true`.
  final String? userActionHint;

  @override
  bool operator ==(Object other) {
    return other is PluginDegraded &&
        other.since == since &&
        other.recoverable == recoverable &&
        other.requiresUserAction == requiresUserAction &&
        other.userActionHint == userActionHint;
  }

  @override
  int get hashCode => Object.hash(since, recoverable, requiresUserAction, userActionHint);

  @override
  String toString() {
    final action = requiresUserAction ? ", requiresUserAction: $userActionHint" : "";
    return "PluginDegraded(since: $since, recoverable: $recoverable$action)";
  }
}

/// The plugin is restarting its managed runtime after an unexpected exit.
final class PluginRestarting extends PluginStatus {
  const PluginRestarting({required this.attempt, this.reason});

  /// 1-based restart attempt within the current failure episode.
  final int attempt;

  /// Why the restart was triggered (e.g. "runtime exited with code 1").
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is PluginRestarting && other.attempt == attempt && other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(attempt, reason);

  @override
  String toString() => "PluginRestarting(attempt: $attempt${reason == null ? "" : ", reason: $reason"})";
}

/// The plugin has terminally failed and will not recover on its own.
///
/// The bridge core latches the first `PluginFailed` it observes and uses it
/// to drive an orderly shutdown with a non-zero exit code. A plugin that is
/// being stopped deliberately must never emit this — the state machine
/// forbids `Failed` after `Stopping`.
final class PluginFailed extends PluginStatus {
  const PluginFailed({required this.reason, this.cause});

  /// Human-readable description of the terminal failure.
  final String reason;

  /// The underlying error, when one exists.
  final Object? cause;

  @override
  bool operator ==(Object other) {
    return other is PluginFailed && other.reason == reason && other.cause == cause;
  }

  @override
  int get hashCode => Object.hash(reason, cause);

  @override
  String toString() => "PluginFailed(reason: $reason${cause == null ? "" : ", cause: $cause"})";
}

/// The plugin's `shutdown()` is in progress.
final class PluginStopping extends PluginStatus {
  const PluginStopping();

  @override
  bool operator ==(Object other) => other is PluginStopping;

  @override
  int get hashCode => (PluginStopping).hashCode;

  @override
  String toString() => "PluginStopping";
}

/// The plugin has fully stopped; the status stream closes after this.
final class PluginStopped extends PluginStatus {
  const PluginStopped();

  @override
  bool operator ==(Object other) => other is PluginStopped;

  @override
  int get hashCode => (PluginStopped).hashCode;

  @override
  String toString() => "PluginStopped";
}
