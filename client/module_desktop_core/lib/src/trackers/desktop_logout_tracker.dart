import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

/// Whether the cross-service desktop logout workflow currently owns lifecycle commands.
enum DesktopLogoutStatus({required final bool locksBridgeControls}) {
  idle(locksBridgeControls: false),
  inProgress(locksBridgeControls: true),
}

/// Layer-2 reactive coordination state shared by logout and bridge controls.
@lazySingleton
class DesktopLogoutTracker() {
  final BehaviorSubject<DesktopLogoutStatus> _statuses = BehaviorSubject<DesktopLogoutStatus>.seeded(
    DesktopLogoutStatus.idle,
    sync: true,
  );

  DesktopLogoutStatus get status => _statuses.value;

  ValueStream<DesktopLogoutStatus> get statuses => _statuses.stream;

  void markInProgress() {
    _statuses.add(DesktopLogoutStatus.inProgress);
  }

  void markIdle() {
    _statuses.add(DesktopLogoutStatus.idle);
  }

  @disposeMethod
  Future<void> dispose() => _statuses.close();
}
