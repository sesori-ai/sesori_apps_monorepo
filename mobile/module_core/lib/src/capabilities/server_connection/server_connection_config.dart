import "package:freezed_annotation/freezed_annotation.dart";

part "server_connection_config.freezed.dart";

@Freezed()
sealed class ServerConnectionConfig with _$ServerConnectionConfig {
  // ignore: no_slop_linter/prefer_required_named_parameters, optional public auth token for disconnected states
  const factory ServerConnectionConfig({
    required String relayHost,
    String? authToken,
  }) = _ServerConnectionConfig;
}
