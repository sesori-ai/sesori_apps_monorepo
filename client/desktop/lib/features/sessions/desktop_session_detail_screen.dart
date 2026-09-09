import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";

/// Desktop composition for the shared interactive transcript and composer.
class const DesktopSessionDetailScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          createSessionDetailCubit(claimProjectView: true, locator: getIt, sessionId: sessionId, projectId: projectId),
      child: DesktopComposerPresentationScope(
        child: SessionDetailActivityOwner(
          routeSource: getIt<RouteSource>(),
          lifecycleSource: getIt<LifecycleSource>(),
          productAnalyticsService: getIt<ProductAnalyticsService>(),
          expectedDetailRoute: AppRouteDef.sessionDetail,
          child: DesktopSessionDetailView(
            projectId: projectId,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            readOnly: readOnly,
            onBack: onBack,
            onShowDiffs: onShowDiffs,
            onOpenSession: onOpenSession,
            onOpenHarnessSettings: onOpenHarnessSettings,
            messageImageRepository: getIt.get<MessageImageRepository>,
            imageSaver: getIt.get<ImageSaver>,
            imageClipboard: getIt.get<ImageClipboard>,
            imageSharer: getIt.get<ImageSharer>,
            canShareImages: defaultTargetPlatform != TargetPlatform.linux,
          ),
        ),
      ),
    );
  }
}

class const DesktopSessionDetailView({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
  required final SessionDetailCapabilityProvider<MessageImageRepository> messageImageRepository,
  required final SessionDetailCapabilityProvider<ImageSaver> imageSaver,
  required final SessionDetailCapabilityProvider<ImageClipboard> imageClipboard,
  required final SessionDetailCapabilityProvider<ImageSharer> imageSharer,
  required final bool canShareImages,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionDetailPresentationScope(
      messageImageRepository: messageImageRepository,
      imageSaver: imageSaver,
      imageClipboard: imageClipboard,
      imageSharer: imageSharer,
      canShareImages: canShareImages,
      openExternalLink: openDesktopExternalLink,
      openSession: onOpenSession,
      openHarnessSettings: onOpenHarnessSettings,
      child: SessionDetailBody(
        onClose: null,
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: null,
        onBack: onBack,
        onShowDiffs: onShowDiffs,
        bottomControlsBuilder: ({required context, required projectId, required sessionId, required state}) =>
            SessionDetailComposerControls(
              projectId: projectId,
              sessionId: sessionId,
              state: state,
            ),
      ),
    );
  }
}
