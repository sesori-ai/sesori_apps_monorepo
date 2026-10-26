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
  Future<void>? _runningCheck;

  DesktopInstallKind get installKind => _updateRepository.installKind;

  ValueStream<DesktopUpdateState> get states => _states.stream;

  DesktopUpdateState get currentState => _states.value;

  ValueStream<DesktopAutomaticUpdates> get automaticUpdates => _automaticUpdates.stream;

  DesktopAutomaticUpdates get currentAutomaticUpdates => _automaticUpdates.value;

  /// macOS has no engine that can check until Sparkle lands.
  bool get _canCheck => switch (_updateRepository.installKind) {
    DesktopInstallKind.linuxPackage || DesktopInstallKind.velopack => true,
    DesktopInstallKind.macosSparkle || DesktopInstallKind.development => false,
  };

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

  /// The single check: the background trigger and "Check for updates" share
  /// it, and a check that starts while one runs (a Velopack download can take
  /// minutes) joins it. A failure keeps the current state and is only logged.
  Future<void> check() {
    if (!_canCheck) {
      return Future<void>.value();
    }
    return _runningCheck ??= _check().whenComplete(() => _runningCheck = null);
  }

  Future<void> _check() async {
    try {
      _states.add(await _updateRepository.check());
    } on Object catch (error, stackTrace) {
      logw("Failed to check for desktop updates", error, stackTrace);
    }
  }

  /// Checks now and then every [checkInterval] while the toggle is on.
  void _scheduleBackgroundChecks() {
    _checkTimer?.cancel();
    _checkTimer = null;
    if (!_canCheck || !_automaticUpdates.value.isEnabled) {
      return;
    }
    unawaited(check());
    _checkTimer = Timer.periodic(checkInterval, (_) => unawaited(check()));
  }

  /// Runs the install kind's restart-to-update step before the helper stops.
  Future<void> prepareRestartToUpdate() => switch (_updateRepository.installKind) {
    DesktopInstallKind.linuxPackage => _updateRepository.relaunchInstalledPackage(),
    // Velopack applies after the helper stops, in applyDownloadedUpdate. The
    // macOS engine arrives in a later step; until then it is never Ready.
    DesktopInstallKind.macosSparkle ||
    DesktopInstallKind.velopack ||
    DesktopInstallKind.development => Future<void>.value(),
  };

  /// Runs after the helper stopped. A Ready Velopack install starts the
  /// updater, which installs the downloaded package silently once this process
  /// exits and, with [restart], opens the new version.
  Future<void> applyDownloadedUpdate({required bool restart}) async {
    if (_updateRepository.installKind == DesktopInstallKind.velopack && _states.value is DesktopUpdateReady) {
      await _updateRepository.applyDownloadedUpdate(restart: restart);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _checkTimer?.cancel();
    await _automaticUpdates.close();
    await _states.close();
  }
}
