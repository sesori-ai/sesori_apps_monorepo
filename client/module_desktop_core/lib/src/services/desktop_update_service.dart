import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/bridge_process_desired_state.dart";
import "../foundation/desktop_automatic_updates.dart";
import "../foundation/models/desktop_install_kind.dart";
import "../foundation/models/desktop_update_state.dart";
import "../repositories/desktop_instance_repository.dart";
import "../repositories/desktop_update_repository.dart";
import "bridge_process_service.dart";

/// How the user asked the desktop to exit.
enum DesktopExitIntent() {
  quit,
  restartToUpdate,
}

/// Layer-3 owner of the update state, the automatic-updates toggle, the one
/// check trigger, and the update step of every exit.
@lazySingleton
class DesktopUpdateService._create({
  required final DesktopUpdateRepository _updateRepository,
  required final DesktopInstanceRepository _instanceRepository,
  required final BridgeProcessService _processService,
}) {
  new({
    required DesktopUpdateRepository updateRepository,
    required DesktopInstanceRepository instanceRepository,
    required BridgeProcessService processService,
  }) : this._create(
         updateRepository: updateRepository,
         instanceRepository: instanceRepository,
         processService: processService,
       );

  static const Duration checkInterval = Duration(hours: 6);

  late final BehaviorSubject<DesktopUpdateState> _states = BehaviorSubject<DesktopUpdateState>.seeded(
    _updateRepository.initialState(),
  );
  final BehaviorSubject<DesktopAutomaticUpdates> _automaticUpdates = BehaviorSubject<DesktopAutomaticUpdates>.seeded(
    DesktopAutomaticUpdates.enabled,
  );
  Timer? _checkTimer;

  ValueStream<DesktopUpdateState> get states => _states.stream;

  DesktopUpdateState get currentState => _states.value;

  ValueStream<DesktopAutomaticUpdates> get automaticUpdates => _automaticUpdates.stream;

  DesktopAutomaticUpdates get currentAutomaticUpdates => _automaticUpdates.value;

  /// Only Linux packages have an engine that can check so far.
  bool get _canCheck => _updateRepository.installKind == DesktopInstallKind.linuxPackage;

  Future<void> start() async {
    try {
      _automaticUpdates.add(await _instanceRepository.readAutomaticUpdates());
    } on Object catch (error, stackTrace) {
      logw("Failed to read the desktop automatic-updates preference; using enabled", error, stackTrace);
    }
    _scheduleBackgroundChecks();
  }

  Future<void> setAutomaticUpdates({required DesktopAutomaticUpdates preference}) async {
    if (preference == _automaticUpdates.value) {
      return;
    }
    await _instanceRepository.writeAutomaticUpdates(preference: preference);
    _automaticUpdates.add(preference);
    _scheduleBackgroundChecks();
  }

  /// The single check: the background trigger and "Check for updates" share it.
  void check() {
    if (!_canCheck) {
      return;
    }
    try {
      _states.add(_updateRepository.readInstalledPackageState());
    } on Object catch (error, stackTrace) {
      logw("Failed to read the installed desktop bundle while checking for updates", error, stackTrace);
    }
  }

  /// Checks now and then every [checkInterval] while the toggle is on.
  void _scheduleBackgroundChecks() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (!_canCheck || !_automaticUpdates.value.isEnabled) {
      return;
    }
    check();
    _checkTimer = Timer.periodic(checkInterval, (_) => check());
  }

  /// Stops the helper, then runs the install kind's exit step. When that step
  /// fails, the helper is restored and the failure is rethrown, so the app
  /// keeps running as before.
  Future<void> prepareExit({required DesktopExitIntent intent}) async {
    final bool helperWasOn = _processService.desiredState == BridgeProcessDesiredState.on;
    await _processService.stop();
    if (intent == DesktopExitIntent.quit) {
      return;
    }
    try {
      await switch (_updateRepository.installKind) {
        DesktopInstallKind.linuxPackage => _updateRepository.relaunchInstalledPackage(),
        // Their engines arrive in later steps; until then they are never Ready.
        DesktopInstallKind.macosSparkle || DesktopInstallKind.velopack || DesktopInstallKind.development =>
          Future<void>.value(),
      };
    } on Object {
      if (helperWasOn) {
        try {
          await _processService.start();
        } on Object catch (error, stackTrace) {
          logw("Failed to restart the desktop bridge after restart to update failed", error, stackTrace);
        }
      }
      rethrow;
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _checkTimer?.cancel();
    await _automaticUpdates.close();
    await _states.close();
  }
}
