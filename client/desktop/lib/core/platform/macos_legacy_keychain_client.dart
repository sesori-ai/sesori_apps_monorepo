import "package:flutter/foundation.dart" show visibleForTesting;
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";

/// Thin MethodChannel client for the non-sandboxed macOS default Keychain.
///
/// WORKAROUND: `flutter_secure_storage_darwin` 0.4.0 still sends attributes
/// that select the Data Protection Keychain when its data-protection option is
/// disabled, causing unsigned and Developer ID builds to fail with
/// `errSecMissingEntitlement` (-34018). Remove this client once the upstream
/// legacy path omits those attributes and passes the desktop runtime probe.
@lazySingleton
class MacOsLegacyKeychainClient.forTesting({required final MethodChannel _channel}) {
  new() : this.forTesting(channel: const MethodChannel(_channelName));

  @visibleForTesting
  this;

  static const String _channelName = "com.sesori.desktop/legacy-keychain";

  Future<String?> read({required String key}) => _channel.invokeMethod<String>("read", <String, String>{"key": key});

  Future<void> write({required String key, required String value}) =>
      _channel.invokeMethod<void>("write", <String, String>{"key": key, "value": value});

  Future<void> delete({required String key}) => _channel.invokeMethod<void>("delete", <String, String>{"key": key});
}
