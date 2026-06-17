import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => NotificationPreferencesCubit(getIt<NotificationPreferencesRepository>()),
        ),
        BlocProvider(
          create: (_) => SettingsCubit(authSession: getIt<AuthSession>()),
        ),
      ],
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final notificationState = context.watch<NotificationPreferencesCubit>().state;
    final settingsState = context.watch<SettingsCubit>().state;
    final isLoggingOut = settingsState is SettingsLoggingOut;

    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, settingsState) {
        if (settingsState is SettingsLoggedOut) {
          context.goRoute(const AppRoute.splash());
        }
        if (settingsState is SettingsLogoutFailed) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(loc.connectErrorUnknown)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(loc.settingsTitle)),
        body: ListView(
          children: [
            const _AccountTile(),
            ...switch (notificationState) {
              NotificationPreferencesLoading() => const [
                SizedBox(height: 32),
                Center(child: CircularProgressIndicator()),
              ],
              NotificationPreferencesLoaded(:final preferences) => [
                SwitchListTile(
                  title: Text(loc.notificationCategoryAiInteraction),
                  subtitle: Text(loc.notificationCategoryAiInteractionDescription),
                  value: preferences[NotificationCategory.aiInteraction] ?? true,
                  onChanged: (enabled) {
                    context.read<NotificationPreferencesCubit>().toggle(
                      NotificationCategory.aiInteraction,
                      enabled: enabled,
                    );
                  },
                ),
                SwitchListTile(
                  title: Text(loc.notificationCategorySessionMessage),
                  subtitle: Text(loc.notificationCategorySessionMessageDescription),
                  value: preferences[NotificationCategory.sessionMessage] ?? true,
                  onChanged: (enabled) {
                    context.read<NotificationPreferencesCubit>().toggle(
                      NotificationCategory.sessionMessage,
                      enabled: enabled,
                    );
                  },
                ),
                SwitchListTile(
                  title: Text(loc.notificationCategoryConnectionStatus),
                  subtitle: Text(loc.notificationCategoryConnectionStatusDescription),
                  value: preferences[NotificationCategory.connectionStatus] ?? true,
                  onChanged: (enabled) {
                    context.read<NotificationPreferencesCubit>().toggle(
                      NotificationCategory.connectionStatus,
                      enabled: enabled,
                    );
                  },
                ),
                SwitchListTile(
                  title: Text(loc.notificationCategorySystemUpdate),
                  subtitle: Text(loc.notificationCategorySystemUpdateDescription),
                  value: preferences[NotificationCategory.systemUpdate] ?? true,
                  onChanged: (enabled) {
                    context.read<NotificationPreferencesCubit>().toggle(
                      NotificationCategory.systemUpdate,
                      enabled: enabled,
                    );
                  },
                ),
              ],
            },
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(loc.settingsLogout),
              textColor: prego.colors.fgErrorPrimary,
              iconColor: prego.colors.fgErrorPrimary,
              trailing: isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: isLoggingOut ? null : () => context.read<SettingsCubit>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header tile showing which account this device is signed in as — the same
/// account surfaced during onboarding (see `_AccountLine`).
///
/// Subscribes to the auth state rather than reading a one-shot snapshot: the
/// session is restored asynchronously on launch, so the account may resolve
/// after this tile first builds. Renders nothing until authenticated, so the
/// trailing [Divider] never hangs above an empty tile.
class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final authSession = getIt<AuthSession>();

    return StreamBuilder<AuthState>(
      stream: authSession.authStateStream,
      initialData: authSession.currentState,
      builder: (context, snapshot) {
        final authState = snapshot.data ?? authSession.currentState;
        if (authState is! AuthAuthenticated) return const SizedBox.shrink();

        final user = authState.user;
        final providerLabel = loc.settingsAccountSignedInWith(user.provider.label);
        final account = user.providerUsername;
        final hasAccount = account != null && account.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(hasAccount ? account : providerLabel),
              subtitle: hasAccount ? Text(providerLabel) : null,
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}
