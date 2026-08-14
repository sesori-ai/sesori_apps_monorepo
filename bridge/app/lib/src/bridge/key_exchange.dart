import "dart:convert";
import "dart:typed_data";

import "package:sesori_shared/sesori_shared.dart";

class KeyExchangeManager(List<int> roomKey, {RelayCryptoService? cryptoService}) {
  final List<int> _roomKey = List<int>.from(roomKey);
  final RelayCryptoService _cryptoService = cryptoService ?? RelayCryptoService();

  /// The key-exchange frame is the initiation signal. The relay does not send
  /// `phone_connected` snapshots when a bridge joins phones already online.
  Future<Uint8List> handleKeyExchange({required RelayKeyExchange message}) async {
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
    final response = Uint8List(bridgePublicKeyBytes.length + encryptedFrame.length);
    response.setRange(0, bridgePublicKeyBytes.length, bridgePublicKeyBytes);
    response.setRange(bridgePublicKeyBytes.length, response.length, encryptedFrame);
    return response;
  }
}
