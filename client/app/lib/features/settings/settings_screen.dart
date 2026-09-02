import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/platform/package_info_client.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/feedback_voice_input_scope.dart";
import "../../core/widgets/legal_document_sheet.dart";

/// Mobile-shell composition for the shared settings view.
class const SettingsScreen({
  super.key,
  required final VoidCallback? onOpenCreatorRecording,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => SettingsCubit(
            authSession: getIt<AuthSession>(),
            notificationRegistrationService: getIt<NotificationRegistrationService>(),
            productAnalyticsService: getIt<ProductAnalyticsService>(),
          ),
        ),
        BlocProvider(
          create: (_) => FeedbackSheetCubit(
            appReviewClient: getIt<AppReviewClient>(),
            feedbackRepository: getIt<FeedbackRepository>(),
            feedbackPromptService: getIt<FeedbackPromptService>(),
            productAnalyticsService: getIt<ProductAnalyticsService>(),
            source: FeedbackSource.settings,
          ),
        ),
        BlocProvider(
          create: (_) => BridgeSettingsCubit(
            service: getIt<BridgeSettingsService>(),
            connectionService: getIt<ConnectionService>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      child: _MobileSettingsView(onOpenCreatorRecording: onOpenCreatorRecording),
    );
  }
}

class const _MobileSettingsView({required final VoidCallback? onOpenCreatorRecording}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsView(
      account: context.watch<SettingsCubit>().state.account,
      connectionBanner: ConnectionBanner.maybeFor(context),
      onClose: () => context.pop(),
      onOpenProfile: () => context.pushRoute(const AppRoute.settingsProfile()),
      onOpenNotifications: () => context.pushRoute(const AppRoute.settingsNotifications()),
      onOpenHarnesses: () => context.pushRoute(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.pushed),
      ),
      onOpenDefaultInput: () => context.pushRoute(const AppRoute.settingsDefaultInput()),
      onOpenRateSesori: () => unawaited(_openRateSesori(context: context)),
      // The dispatcher lands on the new computer's Projects root, which
      // replaces this page.
      onSwitchComputer: ({required bridgeId, required source}) =>
          unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source)),
      additionalSettings: null,
      onOpenCreatorRecording: onOpenCreatorRecording,
      openSupportLink: ({required url}) async {
        await openExternalLink(url: url, mode: UrlLaunchMode.externalApp);
      },
      openLegalDocument: ({required document}) => showLegalDocumentSheet(context, document: document),
      loadAppVersionInfo: _loadAppVersionInfo,
      // The logo's frame reserves the drop-shadow space and therefore the gap
      // down to the product name, matching the existing mobile settings view.
      footerLogo: const SesoriLogo(squareSize: 52),
    );
  }
}

Future<void> _openRateSesori({required BuildContext context}) async {
  final cubit = context.read<FeedbackSheetCubit>();
  final outcome = await showFeedbackSheet(
    context: context,
    cubit: cubit,
    voiceInputScopeBuilder: ({required child}) => FeedbackVoiceInputScope(child: child),
  );
  switch (outcome) {
    case FeedbackSheetOutcomeLoveLeaveReview():
      await cubit.requestStoreReview();
    case FeedbackSheetOutcomeLoveNotNow() || FeedbackSheetOutcomeCouldBeBetter() || FeedbackSheetOutcomeDismissed():
      break;
  }
}

Future<AppVersionInfo?> _loadAppVersionInfo() async {
  try {
    final info = await getIt<PackageInfoClient>().read();
    return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
  } on Object catch (error, stackTrace) {
    logw("Failed to load mobile package information", error, stackTrace);
    return null;
  }
}
