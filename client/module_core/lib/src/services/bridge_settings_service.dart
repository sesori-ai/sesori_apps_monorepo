import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/bridge_settings_repository.dart";
import "../repositories/models/bridge_settings_result.dart";

/// Reads and saves the connected bridge's settings, and owns the last-known
/// YOLO flag so every session page can show it without its own request.
///
/// The flag loads on every connect and follows each load or YOLO save that
/// goes through here. A change made on another surface shows after the next
/// connect or Settings visit; the stale value self-corrects and changes no
/// behaviour, so nothing polls for it.
@lazySingleton
class BridgeSettingsService({
  required final BridgeSettingsRepository _repository,
  required ConnectionService connectionService,
}) with Disposable {
  final BehaviorSubject<bool> _yoloEnabled = BehaviorSubject.seeded(false);
  late final StreamSubscription<ConnectionStatus> _statusSubscription;

  this {
    _statusSubscription = connectionService.status.listen(_onConnectionStatus);
  }

  /// Whether the connected bridge approves every permission request, as last
  /// loaded or saved. Late subscribers get the latest value.
  ValueStream<bool> get yoloEnabled => _yoloEnabled.stream;

  Future<BridgeSettingsLoadResult> load() async {
    final result = await _repository.load();
    switch (result) {
      case BridgeSettingsLoadSupported(:final response):
        _publishYolo(enabled: response.yolo.enabled);
      // Bridges without the aggregate settings route have no YOLO setting.
      case BridgeSettingsLoadLegacyPartial() || BridgeSettingsLoadUnsupported():
        _publishYolo(enabled: false);
      case BridgeSettingsLoadFailure():
        break;
    }
    return result;
  }

  Future<YoloSettingsMutationResult> updateYolo({required bool enabled}) async {
    final result = await _repository.updateYolo(enabled: enabled);
    if (result case YoloSettingsMutationCommitted(:final response)) _publishYolo(enabled: response.enabled);
    return result;
  }

  Future<PullRequestRefreshSettingsMutationResult> updatePullRequestRefresh({required int intervalSeconds}) =>
      _repository.updatePullRequestRefresh(intervalSeconds: intervalSeconds);

  Future<PluginWarmupSettingsMutationResult> updatePluginWarmup({required bool enabled}) =>
      _repository.updatePluginWarmup(enabled: enabled);

  void _onConnectionStatus(ConnectionStatus status) {
    if (status is ConnectionConnected) unawaited(_loadOnConnect());
  }

  Future<void> _loadOnConnect() async {
    try {
      if (await load() case BridgeSettingsLoadFailure(:final error)) {
        logw("Could not load bridge settings on connect; keeping the last-known YOLO flag", error);
      }
    } on Object catch (error, stackTrace) {
      logw("Could not load bridge settings on connect; keeping the last-known YOLO flag", error, stackTrace);
    }
  }

  void _publishYolo({required bool enabled}) {
    if (_yoloEnabled.isClosed || _yoloEnabled.value == enabled) return;
    _yoloEnabled.add(enabled);
  }

  @override
  FutureOr<void> onDispose() async {
    await _statusSubscription.cancel();
    await _yoloEnabled.close();
  }
}
