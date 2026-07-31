import "package:injectable/injectable.dart";
import "package:share_plus/share_plus.dart";

/// Injectable seam around the SharePlus singleton.
@lazySingleton
class SharePlusClient {
  Future<void> share({required ShareParams params}) async {
    await SharePlus.instance.share(params);
  }
}
