import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../platform/external_link_opener.dart";

/// Product-owned capabilities used by the shared session-detail presentation.
///
/// The mobile and desktop shells provide their own DI-resolved repositories,
/// platform adapters, outbound-link policy, and navigation callback. Shared UI
/// never resolves product dependencies from a service locator.
class const SessionDetailPresentationScope({
  super.key,
  required final SessionDetailCapabilityProvider<MessageImageRepository> messageImageRepository,
  required final SessionDetailCapabilityProvider<ImageSaver> imageSaver,
  required final SessionDetailCapabilityProvider<ImageClipboard> imageClipboard,
  required final SessionDetailCapabilityProvider<ImageSharer> imageSharer,
  required final ExternalLinkOpener openExternalLink,
  required final SessionDetailSessionOpener openSession,
  required super.child,
}) extends InheritedWidget {
  static SessionDetailPresentationScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionDetailPresentationScope>();
    assert(scope != null, "SessionDetailPresentationScope was not found in the widget tree");
    return scope!;
  }

  static SessionDetailPresentationScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionDetailPresentationScope>();
    assert(scope != null, "SessionDetailPresentationScope was not found in the widget tree");
    return scope!;
  }

  @override
  bool updateShouldNotify(SessionDetailPresentationScope oldWidget) =>
      messageImageRepository != oldWidget.messageImageRepository ||
      imageSaver != oldWidget.imageSaver ||
      imageClipboard != oldWidget.imageClipboard ||
      imageSharer != oldWidget.imageSharer ||
      openExternalLink != oldWidget.openExternalLink ||
      openSession != oldWidget.openSession;
}

typedef SessionDetailCapabilityProvider<T> = T Function();

typedef SessionDetailSessionOpener = void Function({
  required String projectId,
  required String sessionId,
  required String? sessionTitle,
  required bool readOnly,
});
