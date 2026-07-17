import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/settings_section.dart";

/// Vertical inset between the nav bar and the first section.
const double _contentTopPadding = 10.0;

/// Notification preferences, reached from the settings screen.
///
/// Two sections from the Figma redesign: "AI Notifications" (per-session
/// categories with descriptions) and "System" (app/bridge updates).
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

    return PregoGlassScaffold(
      title: loc.settingsNotificationsTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      banner: ConnectionBanner.maybeFor(context),
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          onPressed: () => context.goRoute(const AppRoute.projects()),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PregoSpacing.xl,
              vertical: _contentTopPadding,
            ),
            child: switch (state) {
              NotificationPreferencesLoading() => const Padding(
                padding: EdgeInsetsDirectional.only(top: PregoSpacing.x4l),
                child: Center(child: CircularProgressIndicator()),
              ),
              NotificationPreferencesLoaded(:final preferences) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    title: loc.notificationSectionAi,
                    child: PregoGroupedRows(
                      children: [
                        _NotificationToggleRow(
                          category: NotificationCategory.aiInteraction,
                          title: loc.notificationCategoryAiInteraction,
                          subtitle: loc.notificationCategoryAiInteractionDescription,
                          preferences: preferences,
                        ),
                        _NotificationToggleRow(
                          category: NotificationCategory.sessionMessage,
                          title: loc.notificationCategorySessionMessage,
                          subtitle: loc.notificationCategorySessionMessageDescription,
                          preferences: preferences,
                        ),
                        _NotificationToggleRow(
                          category: NotificationCategory.connectionStatus,
                          title: loc.notificationCategoryConnectionStatus,
                          subtitle: loc.notificationCategoryConnectionStatusDescription,
                          preferences: preferences,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PregoSpacing.xl),
                  SettingsSection(
                    title: loc.notificationSectionSystem,
                    child: PregoGroupedRows(
                      children: [
                        // The Figma System section renders this row title-only.
                        _NotificationToggleRow(
                          category: NotificationCategory.systemUpdate,
                          title: loc.notificationCategorySystemUpdate,
                          subtitle: null,
                          preferences: preferences,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PregoSpacing.xl),
        ),
      ],
    );
  }
}

class _NotificationToggleRow extends StatelessWidget {
  const _NotificationToggleRow({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.preferences,
    this.isLast = false,
  });

  final NotificationCategory category;
  final String title;
  final String? subtitle;
  final Map<NotificationCategory, bool> preferences;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final enabled = preferences[category] ?? true;
    void toggle({required bool enabled}) {
      context.read<NotificationPreferencesCubit>().toggle(category, enabled: enabled);
    }

    // Merged so assistive tech announces one labelled toggle (title,
    // description, state) instead of an unlabelled switch beside plain text.
    return MergeSemantics(
      child: PregoGroupedRow(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: PregoSwitch(
          value: enabled,
          onChanged: (enabled) => toggle(enabled: enabled),
        ),
        onTap: () => toggle(enabled: !enabled),
        isLast: isLast,
      ),
    );
  }
}
