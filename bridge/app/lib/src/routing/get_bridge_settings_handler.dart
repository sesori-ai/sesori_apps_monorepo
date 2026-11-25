import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings_repository.dart";
import "../services/release_track_settings_service.dart";
import "../services/sleep_prevention_service.dart";
import "../services/tool_group_settings_service.dart";
import "request_handler.dart";

class GetBridgeSettingsHandler({
  required final BridgeSettingsRepository _settingsRepository,
  required final ToolGroupSettingsService _toolGroupSettingsService,
  required final ReleaseTrackSettingsService _releaseTrackSettingsService,
  required final SleepPreventionService _sleepPreventionService,
}) extends GetRequestHandler<BridgeSettingsResponse> {
  this : super(path: "/settings");

  @override
  Future<BridgeSettingsResponse> handle({required RelayRequest request}) async {
    final response = await _settingsRepository.readCommittedResponse();
    return response.copyWith(
      toolGroups: await _toolGroupSettingsService.list(),
      releaseTrack: await _releaseTrackSettingsService.current(),
      preventSleep: await _sleepPreventionService.status(),
    );
  }
}
