import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../platform/external_link_opener.dart";
import "widgets/external_action_modal.dart";
import "widgets/pending_form_modal.dart";

export "widgets/external_action_modal.dart" show SessionExternalActionCubitFactory;
export "widgets/pending_form_modal.dart" show PendingFormCubitFactory;

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

  /// Searches the session's whole history from the Prompts screen.
  required final SessionDetailCapabilityProvider<SessionRepository> sessionRepository,
  required final SessionExternalActionCubitFactory createExternalActionCubit,
  required final PendingFormCubitFactory createPendingFormCubit,

  /// Loads one file's preview from the connected bridge.
  required final FilePreviewCubitFactory createFilePreviewCubit,
  required final bool canShareImages,
  required final ExternalLinkOpener openExternalLink,
  required final SessionDetailSessionOpener openSession,
  required final VoidCallback openHarnessSettings,

  /// Opens the settings that hold the connected bridge's YOLO toggle.
  required final VoidCallback openBridgeSettings,

  /// Shows a session's side chats over its page; null on a shell with no
  /// side-chat surface yet, which then offers no side-question entry.
  required final SideChatOpener? openSideChat,
  required super.child,
}) extends InheritedWidget {
  static SessionDetailPresentationScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionDetailPresentationScope>();
    return scope ?? (throw StateError("SessionDetailPresentationScope was not found in the widget tree"));
  }

  static SessionDetailPresentationScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionDetailPresentationScope>();
    return scope ?? (throw StateError("SessionDetailPresentationScope was not found in the widget tree"));
  }

  /// This scope again around [child], for a route pushed from below it: the
  /// route's content does not inherit the session page's scope. [openSession]
  /// lets the route close itself before it navigates away.
  SessionDetailPresentationScope around({
    required SessionDetailSessionOpener openSession,
    required Widget child,
  }) => SessionDetailPresentationScope(
    messageImageRepository: messageImageRepository,
    imageSaver: imageSaver,
    imageClipboard: imageClipboard,
    imageSharer: imageSharer,
    sessionRepository: sessionRepository,
    createExternalActionCubit: createExternalActionCubit,
    createPendingFormCubit: createPendingFormCubit,
    createFilePreviewCubit: createFilePreviewCubit,
    canShareImages: canShareImages,
    openExternalLink: openExternalLink,
    openSession: openSession,
    openHarnessSettings: openHarnessSettings,
    openBridgeSettings: openBridgeSettings,
    openSideChat: openSideChat,
    child: child,
  );

  @override
  bool updateShouldNotify(SessionDetailPresentationScope oldWidget) =>
      messageImageRepository != oldWidget.messageImageRepository ||
      imageSaver != oldWidget.imageSaver ||
      imageClipboard != oldWidget.imageClipboard ||
      imageSharer != oldWidget.imageSharer ||
      sessionRepository != oldWidget.sessionRepository ||
      createExternalActionCubit != oldWidget.createExternalActionCubit ||
      createPendingFormCubit != oldWidget.createPendingFormCubit ||
      createFilePreviewCubit != oldWidget.createFilePreviewCubit ||
      canShareImages != oldWidget.canShareImages ||
      openExternalLink != oldWidget.openExternalLink ||
      openSession != oldWidget.openSession ||
      openHarnessSettings != oldWidget.openHarnessSettings ||
      openBridgeSettings != oldWidget.openBridgeSettings ||
      openSideChat != oldWidget.openSideChat;
}

typedef SessionDetailCapabilityProvider<T> = T Function();

typedef FilePreviewCubitFactory = FilePreviewCubit Function({required FileReference reference});

typedef SessionDetailSessionOpener = void Function({
  required String projectId,
  required String sessionId,
  required String? sessionTitle,
  required bool readOnly,
});

/// Shows the side chats of [sessionId], read-only when [isArchived]. [context]
/// is the entry's, under this scope.
typedef SideChatOpener = void Function({
  required BuildContext context,
  required String sessionId,
  required String pluginId,
  required SideQuestionAvailability availability,
  required bool isArchived,

  /// Asked in a new side chat as it opens, as Send in `/btw` mode does; null
  /// to open the side chats for the user to type or read.
  required String? initialQuestion,
});
