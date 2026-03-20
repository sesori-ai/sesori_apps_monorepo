import "package:freezed_annotation/freezed_annotation.dart";

part "server_connection_config.freezed.dart";

@Freezed()
sealed class ServerConnectionConfig with _$ServerConnectionConfig {
  const factory ServerConnectionConfig({
    required String relayHost,
    String? authToken,
  }) = _ServerConnectionConfig;
}
