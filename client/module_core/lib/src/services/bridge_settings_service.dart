import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../logging/logging.dart";
import "../repositories/bridge_settings_repository.dart";
import "../repositories/models/bridge_settings_result.dart";

/// Reads and saves the connected bridge's settings, and owns the last-known
/// YOLO setting so every session page can show it without its own request.
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
  final BehaviorSubject<YoloSettingsResponse> _yoloSettings = BehaviorSubject.seeded(_noYolo);
  late final StreamSubscription<ConnectionStatus> _statusSubscription;

  this {
    _statusSubscription = connectionService.status.listen(_onConnectionStatus);
  }

  /// A bridge without the setting: YOLO off, and no per-session choice.
  static const YoloSettingsResponse _noYolo = YoloSettingsResponse(enabled: false);

  /// The connected bridge's YOLO default and whether sessions can override
  /// it, as last loaded or saved. Late subscribers get the latest value.
  ValueStream<YoloSettingsResponse> get yoloSettings => _yoloSettings.stream;

  Future<BridgeSettingsLoadResult> load() async {
    final result = await _repository.load();
    switch (result) {
      case BridgeSettingsLoadSupported(:final response):
        _publishYolo(settings: response.yolo);
      // Bridges without the aggregate settings route have no YOLO setting.
      case BridgeSettingsLoadLegacyPartial() || BridgeSettingsLoadUnsupported():
        _publishYolo(settings: _noYolo);
      case BridgeSettingsLoadFailure():
        break;
    }
    return result;
  }

  Future<YoloSettingsMutationResult> updateYolo({required bool enabled}) async {
    final result = await _repository.updateYolo(enabled: enabled);
    // The save acknowledges only the flag; per-session support stays as loaded.
    if (result case YoloSettingsMutationCommitted(:final response)) {
      _publishYolo(settings: _yoloSettings.value.copyWith(enabled: response.enabled));
    }
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
        logw("Could not load bridge settings on connect; keeping the last-known YOLO setting", error);
      }
    } on Object catch (error, stackTrace) {
      logw("Could not load bridge settings on connect; keeping the last-known YOLO setting", error, stackTrace);
    }
  }

  void _publishYolo({required YoloSettingsResponse settings}) {
    if (_yoloSettings.isClosed || _yoloSettings.value == settings) return;
    _yoloSettings.add(settings);
  }

  @override
  FutureOr<void> onDispose() async {
    await _statusSubscription.cancel();
    await _yoloSettings.close();
  }
}
