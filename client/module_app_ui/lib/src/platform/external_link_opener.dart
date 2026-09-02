import "package:sesori_dart_core/sesori_dart_core.dart";

/// Product-owned policy for opening links from shared presentation code.
typedef ExternalLinkOpener = Future<bool> Function({
  required Uri url,
  required UrlLaunchMode mode,
});
