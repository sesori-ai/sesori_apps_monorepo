import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";

/// Mobile-shell composition for the shared profile view.
class const ProfileScreen({super.key}) extends StatelessWidget {
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
          create: (_) => ProductAnalyticsPreferenceCubit(service: getIt<ProductAnalyticsService>()),
        ),
      ],
      child: const _MobileProfileView(),
    );
  }
}

class const _MobileProfileView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsCubit = context.read<SettingsCubit>();
    return ProfileView(
      account: context.watch<SettingsCubit>().state.account,
      connectionBanner: ConnectionBanner.maybeFor(context),
      onClose: () => context.goRoute(const AppRoute.projects()),
      logout: () async {
        await settingsCubit.logout();
        final succeeded = settingsCubit.state.logoutStatus == SettingsLogoutStatus.success;
        if (succeeded && context.mounted) context.goRoute(const AppRoute.splash());
        return succeeded;
      },
    );
  }
}
