import "dart:convert";

import "package:crypto/crypto.dart" show Hmac, sha1;
import "package:sesori_shared/sesori_shared.dart"
    show DeviceCanvasTurnConfiguration, maxDeviceCanvasStreamOperationIdLength, maxDeviceCanvasTurnUsernameByteCount;

import "device_canvas_turn_credential_issuer.dart";

class DeviceCanvasTurnCredentialBuilder({
  required List<String> urls,
  required List<int> sharedSecret,
  Duration credentialLifetime = const Duration(minutes: 5),
}) implements DeviceCanvasTurnCredentialIssuer {
  static const int minimumSharedSecretBytes = 32;
  static final RegExp _opaqueOperationIdPattern = RegExp(r"^[A-Za-z0-9_-]+$");

  final List<String> _urls = _validateAndCopyUrls(urls);
  final List<int> _sharedSecret = _validateAndCopySecret(sharedSecret);
  final Duration _credentialLifetime = _validateLifetime(credentialLifetime);

  DeviceCanvasTurnConfiguration build({
    required String operationId,
    required int leaseExpiresAt,
    required DateTime now,
  }) {
    if (operationId.isEmpty ||
        operationId.length > maxDeviceCanvasStreamOperationIdLength ||
        !_opaqueOperationIdPattern.hasMatch(operationId)) {
      throw ArgumentError("operationId must be a bounded opaque identifier", "operationId");
    }

    final nowSeconds = now.microsecondsSinceEpoch ~/ Duration.microsecondsPerSecond;
    final leaseExpirySeconds = leaseExpiresAt ~/ Duration.millisecondsPerSecond;
    if (leaseExpirySeconds <= nowSeconds) {
      throw StateError("TURN credential lease is not valid in a future whole second");
    }

    final lifetimeExpirySeconds =
        (now.microsecondsSinceEpoch + _credentialLifetime.inMicroseconds) ~/ Duration.microsecondsPerSecond;
    final expirySeconds = lifetimeExpirySeconds < leaseExpirySeconds ? lifetimeExpirySeconds : leaseExpirySeconds;
    if (expirySeconds <= nowSeconds) {
      throw StateError("TURN credential lifetime does not reach a future whole second");
    }

    final username = "$expirySeconds:$operationId";
    if (utf8.encode(username).length > maxDeviceCanvasTurnUsernameByteCount) {
      throw StateError("Generated TURN username exceeds the protocol byte limit");
    }

    final credential = base64Encode(Hmac(sha1, _sharedSecret).convert(utf8.encode(username)).bytes);
    final configuration = DeviceCanvasTurnConfiguration(
      urls: _urls,
      username: username,
      credential: credential,
      expiresAt: expirySeconds * Duration.millisecondsPerSecond,
    );
    if (!configuration.isValid) {
      throw StateError("Generated TURN configuration is invalid");
    }
    return configuration;
  }

  @override
  Future<DeviceCanvasTurnConfiguration> issue({
    required String operationId,
    required int leaseExpiresAt,
    required DateTime now,
  }) async => build(operationId: operationId, leaseExpiresAt: leaseExpiresAt, now: now);

  static List<String> _validateAndCopyUrls(List<String> urls) {
    final validation = DeviceCanvasTurnConfiguration(
      urls: List<String>.of(urls),
      username: "validation",
      credential: "validation",
      expiresAt: 1,
    );
    final canonicalUrls = validation.canonicalUrls;
    if (canonicalUrls == null) {
      throw ArgumentError("urls must be a nonempty, canonicalizable, nonduplicate TURN URL list", "urls");
    }
    return List<String>.unmodifiable(canonicalUrls);
  }

  static List<int> _validateAndCopySecret(List<int> sharedSecret) {
    if (sharedSecret.length < minimumSharedSecretBytes || sharedSecret.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError("sharedSecret must contain at least 32 bytes", "sharedSecret");
    }
    return List<int>.unmodifiable(sharedSecret);
  }

  static Duration _validateLifetime(Duration credentialLifetime) {
    if (credentialLifetime <= Duration.zero) {
      throw ArgumentError("credentialLifetime must be positive", "credentialLifetime");
    }
    return credentialLifetime;
  }
}
