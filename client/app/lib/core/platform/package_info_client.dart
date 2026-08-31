import "package:injectable/injectable.dart";
import "package:package_info_plus/package_info_plus.dart";

@lazySingleton
class PackageInfoClient() {
  Future<PackageInfo> read() => PackageInfo.fromPlatform();
}
