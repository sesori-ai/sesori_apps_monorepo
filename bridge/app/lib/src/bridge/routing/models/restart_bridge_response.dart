import 'package:freezed_annotation/freezed_annotation.dart';

part 'restart_bridge_response.freezed.dart';
part 'restart_bridge_response.g.dart';

/// Acknowledgement returned by `POST /global/restart` before the bridge hands
/// off to its successor. Bridge-only (the phone observes the actual restart via
/// the relay disconnect → reconnect), so it lives here rather than in
/// `sesori_shared`.
@Freezed(toJson: true)
sealed class RestartBridgeResponse with _$RestartBridgeResponse {
  const factory RestartBridgeResponse({required bool restarting}) = _RestartBridgeResponse;
}
