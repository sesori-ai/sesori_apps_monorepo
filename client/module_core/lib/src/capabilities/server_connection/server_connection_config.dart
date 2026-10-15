import "package:freezed_annotation/freezed_annotation.dart";

part "server_connection_config.freezed.dart";

@Freezed()
sealed class ServerConnectionConfig with _$ServerConnectionConfig {
  const factory({
    required String relayHost,
    required String? authToken,

    /// The computer (bridge id) this connection targets. `null` lets the relay
    /// route to the account's most recently connected bridge; the id it
    /// reports is then adopted here once the connection is established.
    required String? bridgeId,
  }) = _ServerConnectionConfig;
}
