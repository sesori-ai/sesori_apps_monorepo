import "dart:convert";

import "package:cryptography/cryptography.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../api/desktop_update_feed_api.dart";
import "../foundation/desktop_update_public_key.dart";

/// Layer-2 trust check: the feed bytes must carry an Ed25519 signature from
/// the compiled update key. Velopack then trusts the feed's package SHA-256.
@lazySingleton
class DesktopUpdateFeedValidator.forTesting({required final String _publicKey}) {
  new() : this.forTesting(publicKey: desktopUpdatePublicKey);

  @visibleForTesting
  this;

  /// Throws a [FormatException] unless [feed] is signed by the update key.
  Future<void> verify({required DesktopUpdateFeed feed}) async {
    final bool valid = await Ed25519().verify(
      feed.bytes,
      signature: Signature(
        base64Decode(feed.signature),
        publicKey: SimplePublicKey(base64Decode(_publicKey), type: KeyPairType.ed25519),
      ),
    );
    if (!valid) {
      throw const FormatException("The desktop update feed signature does not match the update key");
    }
  }
}
