import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Reads the project name carried by the current location's query string.
String? currentProjectName(BuildContext context) {
  return GoRouterState.of(context).uri.queryParameters[projectNameQueryParam];
}
