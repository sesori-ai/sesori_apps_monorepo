import "package:app_links/app_links.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: DeepLinkSource)
class AppLinksDeepLinkSource implements DeepLinkSource {
  @override
  Stream<Uri> get linkStream => AppLinks().uriLinkStream;
}
