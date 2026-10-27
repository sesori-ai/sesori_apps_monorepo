import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/desktop_automatic_updates.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_update_state.dart";
import "../repositories/desktop_instance_repository.dart";
import "../repositories/desktop_update_repository.dart";

/// Layer-3 owner of the update state, the automatic-updates toggle, the one
/// check trigger, and the install kind's restart-to-update step.
@lazySingleton
class DesktopUpdateService._create({
  required final DesktopUpdateRepository _updateRepository,
  required final DesktopInstanceRepository _instanceRepository,
}) {
  new({
    required DesktopUpdateRepository updateRepository,
    required DesktopInstanceRepository instanceRepository,
  }) : this._create(
         updateRepository: updateRepository,
         instanceRepository: instanceRepository,
       );

  static const Duration checkInterval = Duration(hours: 6);

  late final BehaviorSubject<DesktopUpdateState> _states = BehaviorSubject<DesktopUpdateState>.seeded(
    _updateRepository.initialState(),
  );
  final BehaviorSubject<DesktopAutomaticUpdates> _automaticUpdates = BehaviorSubject<DesktopAutomaticUpdates>.seeded(
    DesktopAutomaticUpdates.enabled,
  );
  Timer? _checkTimer;
  Future<bool>? _runningCheck;
  StreamSubscription<DesktopUpdateState>? _sparkleSubscription;

  DesktopInstallKind get installKind => _updateRepository.installKind;

  ValueStream<DesktopUpdateState> get states => _states.stream;

  DesktopUpdateState get currentState => _states.value;

  ValueStream<DesktopAutomaticUpdates> get automaticUpdates => _automaticUpdates.stream;

  DesktopAutomaticUpdates get currentAutomaticUpdates => _automaticUpdates.value;

  /// Each "Restart to Update" chosen in the macOS app menu or update window;
  /// `BridgeControlCubit` owns the exit it starts. Only a started Sparkle emits.
  Stream<void> get restartRequests => _updateRepository.sparkleRestartRequests;

  bool get _canCheck => installKind != DesktopInstallKind.development;

  /// Sparkle schedules its own background checks; the other engines share this
  /// service's timer.
  bool get _ownsCheckTimer => switch (installKind) {
    DesktopInstallKind.linuxPackage || DesktopInstallKind.velopack => true,
    DesktopInstallKind.macosSparkle || DesktopInstallKind.development => false,
  };

  Future<void> start() async {
    try {
      _automaticUpdates.add(await _instanceRepository.readAutomaticUpdates());
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop automatic-updates preference; using enabled", error, stackTrace);
    }
    if (installKind == DesktopInstallKind.macosSparkle) {
      await _startSparkle();
    }
    _scheduleBackgroundChecks();
  }

  Future<void> _startSparkle() async {
    _sparkleSubscription = _updateRepository.sparkleDownloads.listen(_states.add);
    try {
      await _updateRepository.startSparkle(automaticChecks: _automaticUpdates.value.isEnabled);
    } on Object catch (error, stackTrace) {
      logw("Failed to start Sparkle; macOS updates stay idle", error, stackTrace);
    }
  }

  Future<void> setAutomaticUpdates({required DesktopAutomaticUpdates preference}) async {
    if (preference == _automaticUpdates.value) {
      return;
    }
    await _instanceRepository.writeAutomaticUpdates(preference: preference);
    _automaticUpdates.add(preference);
    if (installKind == DesktopInstallKind.macosSparkle) {
      await _updateRepository.setSparkleAutomaticChecks(enabled: preference.isEnabled);
    }
    _scheduleBackgroundChecks();
  }

  /// The single check: the background trigger and "Check for updates" share
  /// it, and a check that starts while one runs (a Velopack download can take
  /// minutes) joins it. Completes with whether the check finished; a failure
  /// keeps the current state and is only logged.
  Future<bool> check() {
    if (!_canCheck) {
      return Future<bool>.value(false);
    }
    return _runningCheck ??= _check().whenComplete(() => _runningCheck = null);
  }

  Future<bool> _check() async {
    try {
      if (installKind == DesktopInstallKind.macosSparkle) {
        // Sparkle reports a downloaded update on its own stream.
        await _updateRepository.checkSparkle();
      } else {
        _states.add(await _updateRepository.check());
      }
      return true;
    } on Object catch (error, stackTrace) {
      logw("Failed to check for desktop updates", error, stackTrace);
      return false;
    }
  }

  /// Checks now and then every [checkInterval] while the toggle is on.
  void _scheduleBackgroundChecks() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (!_ownsCheckTimer || !_automaticUpdates.value.isEnabled) {
      return;
    }
    unawaited(check());
    _checkTimer = Timer.periodic(checkInterval, (_) => unawaited(check()));
  }

  /// Runs the install kind's restart-to-update step before the helper stops.
  Future<void> prepareRestartToUpdate() => switch (_updateRepository.installKind) {
    DesktopInstallKind.linuxPackage => _updateRepository.relaunchInstalledPackage(),
    // Velopack and Sparkle apply after the helper stops, in applyDownloadedUpdate.
    DesktopInstallKind.macosSparkle ||
    DesktopInstallKind.velopack ||
    DesktopInstallKind.development => Future<void>.value(),
  };

  /// Runs after the helper stopped. A Ready Velopack install starts the
  /// updater, which installs the downloaded package silently once this process
  /// exits and, with [restart], opens the new version. Sparkle installs on
  /// normal termination by itself; with [restart] it installs now and relaunches.
  Future<void> applyDownloadedUpdate({required bool restart}) async {
    if (_states.value is! DesktopUpdateReady) {
      return;
    }
    switch (installKind) {
      case DesktopInstallKind.velopack:
        await _updateRepository.applyDownloadedUpdate(restart: restart);
      case DesktopInstallKind.macosSparkle when restart:
        await _updateRepository.installSparkleUpdateAndRelaunch();
      case DesktopInstallKind.macosSparkle || DesktopInstallKind.linuxPackage || DesktopInstallKind.development:
        return;
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _checkTimer?.cancel();
    await _sparkleSubscription?.cancel();
    await _automaticUpdates.close();
    await _states.close();
  }
}
