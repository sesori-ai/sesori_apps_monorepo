import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

class KeyExchangeManager {
  final List<int> _roomKey;
  final Map<int, bool> _pendingExchanges = <int, bool>{};
  final RelayCryptoService _cryptoService;

  KeyExchangeManager(List<int> roomKey, {RelayCryptoService? cryptoService})
    : _roomKey = List<int>.from(roomKey),
      _cryptoService = cryptoService ?? RelayCryptoService();

  void startExchange(int connID) {
    _pendingExchanges.remove(connID);
    _pendingExchanges[connID] = true;
  }

  Future<List<int>> handleKeyExchange(int connID, RelayKeyExchange message) async {
    final isPending = _pendingExchanges[connID] ?? false;
    if (!isPending) {
      throw StateError("no pending exchange for connID $connID");
    }

    final bridgeKeyPair = await _cryptoService.generateKeyPair();
    final bridgePublicKey = await bridgeKeyPair.extractPublicKey();
    final bridgePublicKeyBytes = bridgePublicKey.bytes;

    final phonePublicKeyBytes = base64Url.decode(
      base64Url.normalize(message.publicKey),
    );
    final phonePublicKey = _cryptoService.decodePublicKeyFromBytes(
      phonePublicKeyBytes,
    );

    final sharedSecret = await _cryptoService.deriveSharedSecret(
      bridgeKeyPair,
      phonePublicKey,
    );
    final ephemeralKey = await _cryptoService.deriveEncryptionKey(sharedSecret);

    final readyMessage = RelayMessage.ready(
      publicKey: base64Url.encode(bridgePublicKeyBytes).replaceAll("=", ""),
      roomKey: base64Url.encode(_roomKey).replaceAll("=", ""),
    );
    final readyJSON = utf8.encode(jsonEncode(readyMessage.toJson()));

    final encryptor = _cryptoService.createSessionEncryptor(ephemeralKey);
    final encryptedFrame = await frame(readyJSON, encryptor);

    _pendingExchanges.remove(connID);
    return [...bridgePublicKeyBytes, ...encryptedFrame];
  }

  void removeExchange(int connID) {
    _pendingExchanges.remove(connID);
  }
}
