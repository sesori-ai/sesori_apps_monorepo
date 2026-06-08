import "package:flutter/widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../core/routing/app_router.dart";
import "../../../core/widgets/session_split/session_split_scope.dart";

/// Opens a session detail route adaptively based on split context.
///
/// In a [SessionSplitScope] with [isSplit] true, uses [replaceRoute] so the
/// right panel updates without adding to the navigation stack.
/// Otherwise uses [pushRoute] for standard fullscreen push behavior.
///
/// Always preserves the [readOnly] parameter on the constructed route.
void openAdaptiveSessionDetail({
  required BuildContext context,
  required String projectId,
  required String sessionId,
  required bool readOnly,
  required String? sessionTitle,
}) {
  final route = AppRoute.sessionDetail(
    projectId: projectId,
    sessionId: sessionId,
    readOnly: readOnly,
    sessionTitle: sessionTitle,
  );
  final splitScope = SessionSplitScope.maybeOf(context);
  if (splitScope != null && splitScope.isSplit) {
    context.replaceRoute(route);
  } else {
    context.pushRoute(route);
  }
}
