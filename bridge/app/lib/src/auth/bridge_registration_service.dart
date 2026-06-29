import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "bridge_id_provider.dart";
import "bridge_id_storage.dart";
import "bridge_registration_api.dart";
import "bridge_registration_repository.dart";
import "token_refresher.dart";

/// Registers this bridge with the auth server and tracks the assigned
/// bridge id across reconnects.
///
/// Registration is memoized per process: once [ensureRegistered] succeeds it
/// returns immediately on subsequent calls until [handleBridgeRevoked]
/// resets it (relay close code 4006 — bridge revoked).
///
/// The persisted bridge id is read from [BridgeIdStorage]; legacy ids from an
/// older `token.json` are copied into that storage by `BridgeIdMigrationService`
/// before authentication, so this service never reads `token.json`.
class BridgeRegistrationService implements BridgeIdProvider {
  final BridgeRegistrationRepository _repository;
  final TokenRefresher _tokenRefresher;
  final BridgeIdStorage _bridgeIdStorage;
  final String _hostName;
  final String _platform;

  bool _registered = false;
  String? _bridgeId;

  BridgeRegistrationService({
    required BridgeRegistrationRepository repository,
    required TokenRefresher tokenRefresher,
    required BridgeIdStorage bridgeIdStorage,
    required String hostName,
    required String platform,
  }) : _repository = repository,
       _tokenRefresher = tokenRefresher,
       _bridgeIdStorage = bridgeIdStorage,
       _hostName = sanitizeBridgeName(hostName),
       _platform = platform;

  /// The bridge platform name reported to the auth server.
  static String currentPlatformName() {
    if (Platform.isMacOS) return "macos";
    if (Platform.isWindows) return "windows";
    if (Platform.isLinux) return "linux";
    throw UnsupportedError("Unsupported platform: ${Platform.operatingSystem}");
  }

  /// Clamps a bridge name to the auth server's 1-120 character contract so an
  /// exotic hostname can never fail registration with a 400.
  static String sanitizeBridgeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "sesori-bridge";
    return trimmed.length <= 120 ? trimmed : trimmed.substring(0, 120);
  }

  @override
  String? get bridgeId => _bridgeId;

  /// Ensures this bridge is registered with the auth server.
  ///
  /// Posts the persisted bridge id (if any) so the server updates the
  /// existing registration; the returned id is persisted to its file.
  /// Throws on failure so the caller can fail the connect attempt and retry
  /// on its existing backoff.
  Future<void> ensureRegistered() async {
    if (_registered) {
      return;
    }

    final existingId = await _bridgeIdStorage.read();
    final summary = await _withAccessTokenRetry(
      (accessToken) => _repository.register(
        name: _hostName,
        platform: _platform,
        bridgeId: existingId,
        accessToken: accessToken,
      ),
    );

    _bridgeId = summary.id;
    if (existingId != summary.id) {
      await _bridgeIdStorage.write(bridgeId: summary.id);
    }
    _registered = true;
  }

  /// Clears the in-memory and persisted bridge id and resets the
  /// registration memoization after the relay reported this bridge as
  /// revoked (close code 4006).
  ///
  /// The next [ensureRegistered] call re-registers from scratch and receives
  /// a fresh server-minted bridge id.
  Future<void> handleBridgeRevoked() async {
    _registered = false;
    _bridgeId = null;
    try {
      await _bridgeIdStorage.clear();
    } on Object catch (error, stackTrace) {
      // Best-effort: a stale persisted id self-heals because re-registering
      // with a revoked id makes the server mint a fresh one. Swallowing here
      // keeps a transient filesystem error from aborting the reconnect path.
      Log.w("Failed to clear persisted bridge id after revocation", error, stackTrace);
    }
  }

  /// Removes this bridge's registration on the auth server.
  ///
  /// Does nothing when no bridge id is persisted. A 404 (already revoked)
  /// counts as success; any other failure is rethrown. Clears the persisted
  /// bridge id once the server no longer holds the registration.
  Future<void> unregister() async {
    final bridgeId = await _bridgeIdStorage.read();
    if (bridgeId == null) {
      return;
    }

    try {
      await _withAccessTokenRetry(
        (accessToken) => _repository.unregister(bridgeId: bridgeId, accessToken: accessToken),
      );
    } on BridgeRegistrationException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
    }
    await _bridgeIdStorage.clear();
  }

  Future<T> _withAccessTokenRetry<T>(Future<T> Function(String accessToken) action) async {
    final accessToken = await _tokenRefresher.getAccessToken();
    try {
      return await action(accessToken);
    } on BridgeRegistrationException catch (e) {
      if (e.statusCode != 401) {
        rethrow;
      }
      final refreshedToken = await _tokenRefresher.getAccessToken(forceRefresh: true);
      return action(refreshedToken);
    }
  }
}
