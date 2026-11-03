import "package:share_plus/share_plus.dart";

/// Seam around the SharePlus singleton, so tests can replace it.
class SharePlusClient() {
  Future<void> share({required ShareParams params}) async {
    await SharePlus.instance.share(params);
  }
}
