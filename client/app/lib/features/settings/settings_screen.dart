import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";

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
    final isLoggingOut = settingsState.logoutStatus == SettingsLogoutStatus.inProgress;

    return BlocListener<SettingsCubit, SettingsState>(
      // Only react to logout transitions — account updates from the auth
      // stream also emit new states and must not re-trigger navigation.
      listenWhen: (prev, curr) => prev.logoutStatus != curr.logoutStatus,
      listener: (context, settingsState) {
        switch (settingsState.logoutStatus) {
          case SettingsLogoutStatus.success:
            context.goRoute(const AppRoute.splash());
          case SettingsLogoutStatus.failure:
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text(loc.connectErrorUnknown)));
          case SettingsLogoutStatus.idle:
          case SettingsLogoutStatus.inProgress:
            break;
        }
      },
      child: PregoGlassScaffold(
        title: loc.settingsTitle,
        banner: ConnectionBanner.maybeFor(context),
        slivers: [
          SliverList.list(
            children: [
              _AccountTile(account: settingsState.account),
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
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PregoSpacing.xl),
          ),
        ],
      ),
    );
  }
}

/// Header tile showing which account this device is signed in as — the same
/// account surfaced during onboarding (see `_AccountLine`).
///
/// The [account] is sourced from [SettingsCubit] state (which subscribes to
/// the auth stream), so it stays in sync as the session resolves on launch.
/// Renders nothing when there is no account, so the trailing [Divider] never
/// hangs above an empty tile.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final AuthUser? account;

  @override
  Widget build(BuildContext context) {
    final user = account;
    if (user == null) return const SizedBox.shrink();

    final loc = context.loc;
    final providerLabel = loc.settingsAccountSignedInWith(user.provider.label);
    final username = user.providerUsername;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(switch (username) {
            final String name when name.isNotEmpty => name,
            _ => providerLabel,
          }),
          subtitle: switch (username) {
            final String name when name.isNotEmpty => Text(providerLabel),
            _ => null,
          },
        ),
        const Divider(),
      ],
    );
  }
}
