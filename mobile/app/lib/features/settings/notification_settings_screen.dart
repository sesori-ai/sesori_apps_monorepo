import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationPreferencesCubit(getIt<NotificationPreferencesRepository>()),
      child: const _NotificationSettingsBody(),
    );
  }
}

class _NotificationSettingsBody extends StatelessWidget {
  const _NotificationSettingsBody();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<NotificationPreferencesCubit>().state;

    return Scaffold(
      appBar: AppBar(title: Text(loc.notificationSettingsTitle)),
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
          ],
        ),
      },
    );
  }
}
