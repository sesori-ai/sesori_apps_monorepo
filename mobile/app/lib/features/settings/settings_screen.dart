import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

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
    final state = context.watch<NotificationPreferencesCubit>().state;

    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, settingsState) {
        if (settingsState is SettingsLoggedOut) {
          context.goRoute(const AppRoute.splash());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(loc.settingsTitle)),
        body: switch (state) {
          NotificationPreferencesLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          NotificationPreferencesLoaded(:final preferences) => ListView(
            children: [
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
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(loc.settingsLogout),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => context.read<SettingsCubit>().logout(),
              ),
            ],
          ),
        },
      ),
    );
  }
}
