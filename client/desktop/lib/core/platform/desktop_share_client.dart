import "package:injectable/injectable.dart";
import "package:share_plus/share_plus.dart";

/// Injectable seam around the desktop SharePlus singleton.
@lazySingleton
class DesktopShareClient() {
  Future<void> share({required ShareParams params}) async {
    await SharePlus.instance.share(params);
  }
}
