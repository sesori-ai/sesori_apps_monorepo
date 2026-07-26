import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

class KeyExchangeManager {
  final List<int> _roomKey;
  final RelayCryptoService _cryptoService;

  KeyExchangeManager(List<int> roomKey, {RelayCryptoService? cryptoService})
    : _roomKey = List<int>.from(roomKey),
      _cryptoService = cryptoService ?? RelayCryptoService();

  /// The key-exchange frame is the initiation signal. The relay does not send
  /// `phone_connected` snapshots when a bridge joins phones already online.
  Future<List<int>> handleKeyExchange({required RelayKeyExchange message}) async {
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
      peerPublicKey: phonePublicKey,
    );
    final ephemeralKey = await _cryptoService.deriveEncryptionKey(sharedSecret);

    final readyMessage = RelayMessage.ready(
      publicKey: base64Url.encode(bridgePublicKeyBytes).replaceAll("=", ""),
      roomKey: base64Url.encode(_roomKey).replaceAll("=", ""),
    );
    final readyJSON = utf8.encode(jsonEncode(readyMessage.toJson()));

    final encryptor = _cryptoService.createSessionEncryptor(ephemeralKey);
    final encryptedFrame = await frame(readyJSON, encryptor: encryptor);

    return [...bridgePublicKeyBytes, ...encryptedFrame];
  }
}
