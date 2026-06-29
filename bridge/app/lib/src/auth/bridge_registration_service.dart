import "dart:io";

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
class BridgeRegistrationService implements BridgeIdProvider {
  final BridgeRegistrationRepository _repository;
  final TokenRefresher _tokenRefresher;
  final BridgeIdStorage _bridgeIdStorage;
  final Future<String?> Function() _readLegacyBridgeId;
  final String _hostName;
  final String _platform;

  bool _registered = false;
  bool _legacyAdoptionAttempted = false;
  String? _bridgeId;

  BridgeRegistrationService({
    required BridgeRegistrationRepository repository,
    required TokenRefresher tokenRefresher,
    required BridgeIdStorage bridgeIdStorage,
    required Future<String?> Function() readLegacyBridgeId,
    required String hostName,
    required String platform,
  }) : _repository = repository,
       _tokenRefresher = tokenRefresher,
       _bridgeIdStorage = bridgeIdStorage,
       _readLegacyBridgeId = readLegacyBridgeId,
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

    final existingId = await _bridgeIdStorage.read() ?? await _adoptLegacyBridgeId();
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
    await _bridgeIdStorage.clear();
  }

  /// Removes this bridge's registration on the auth server.
  ///
  /// Does nothing when no bridge id is persisted. A 404 (already revoked)
  /// counts as success; any other failure is rethrown.
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
  }

  /// Adopts the bridge id an older bridge persisted inside `token.json`, once.
  ///
  /// Runs only when [BridgeIdStorage] is empty (a fresh install or an upgrade
  /// before the first registration) and at most once per process. Writing the
  /// adopted id through to storage means subsequent calls read it from there
  /// and never touch the legacy file again.
  Future<String?> _adoptLegacyBridgeId() async {
    if (_legacyAdoptionAttempted) {
      return null;
    }
    _legacyAdoptionAttempted = true;

    final legacy = await _readLegacyBridgeId();
    if (legacy != null) {
      await _bridgeIdStorage.write(bridgeId: legacy);
    }
    return legacy;
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
