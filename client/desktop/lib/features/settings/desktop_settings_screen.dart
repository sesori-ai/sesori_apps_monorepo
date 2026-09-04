import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "desktop_attention_preference_section.dart";

/// Desktop-shell composition for the shared settings view.
class const DesktopSettingsScreen({
  super.key,
  required final VoidCallback onClose,
  required final VoidCallback onOpenProfile,
  required final VoidCallback onOpenHarnesses,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => BridgeSettingsCubit(
            repository: getIt<BridgeSettingsRepository>(),
            connectionService: getIt<ConnectionService>(),
          ),
        ),
        BlocProvider(
          create: (_) => DesktopAttentionPreferenceCubit(
            service: getIt<DesktopAttentionService>(),
          ),
        ),
      ],
      child: _DesktopSettingsView(
        onClose: onClose,
        onOpenProfile: onOpenProfile,
        onOpenHarnesses: onOpenHarnesses,
      ),
    );
  }
}

class const _DesktopSettingsView({
  required final VoidCallback onClose,
  required final VoidCallback onOpenProfile,
  required final VoidCallback onOpenHarnesses,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthUser? account = switch (context.watch<AuthGateCubit>().state) {
      AuthGateSignedIn(:final user) => user,
      AuthGateChecking() || AuthGateSignedOut() => null,
    };

    return SettingsView(
      account: account,
      connectionBanner: null,
      onClose: onClose,
      onOpenProfile: onOpenProfile,
      // Desktop intentionally does not inject the mobile push-notification
      // preference capability.
      onOpenNotifications: null,
      onOpenHarnesses: onOpenHarnesses,
      additionalSettings: const DesktopAttentionPreferenceSection(),
      openSupportLink: ({required url}) async {
        await openDesktopExternalLink(url: url, mode: UrlLaunchMode.externalApp);
      },
      openLegalDocument: ({required document}) async {
        await openDesktopExternalLink(
          url: LegalLinks.uriFor(document: document),
          mode: UrlLaunchMode.externalApp,
        );
      },
      loadAppVersionInfo: _loadAppVersionInfo,
      footerLogo: null,
    );
  }
}

Future<AppVersionInfo?> _loadAppVersionInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
  } on Object catch (error, stackTrace) {
    logw("Failed to load desktop package information", error, stackTrace);
    return null;
  }
}
