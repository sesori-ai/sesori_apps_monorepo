import "bridge_id_storage.dart";

/// Copies a bridge id persisted by an older bridge inside `token.json` into the
/// dedicated [BridgeIdStorage], exactly once.
///
/// Earlier bridges stored the server-minted id alongside the tokens. It now
/// lives in its own file, so an upgraded install must copy the legacy id across
/// before any auth path rewrites `token.json` — the new `TokenData` no longer
/// serializes `bridgeId`, so the first token save would otherwise erase the
/// only copy and force a duplicate registration. [migrate] must therefore run
/// before the first authentication, and its failures propagate so startup
/// retries the copy instead of proceeding with an empty storage.
class BridgeIdMigrationService {
  final BridgeIdStorage _bridgeIdStorage;
  final Future<String?> Function() _readLegacyBridgeId;

  BridgeIdMigrationService({
    required BridgeIdStorage bridgeIdStorage,
    required Future<String?> Function() readLegacyBridgeId,
  }) : _bridgeIdStorage = bridgeIdStorage,
       _readLegacyBridgeId = readLegacyBridgeId;

  /// Adopts the legacy bridge id when [BridgeIdStorage] is empty.
  ///
  /// A no-op once the storage already holds an id (a fresh install never had a
  /// legacy id, and a completed migration is idempotent). Any read/write
  /// failure propagates so the caller can abort startup and retry before a
  /// token save erases the legacy source.
  Future<void> migrate() async {
    if (await _bridgeIdStorage.read() != null) {
      return;
    }
    final legacy = await _readLegacyBridgeId();
    if (legacy != null) {
      await _bridgeIdStorage.write(bridgeId: legacy);
    }
  }
}
