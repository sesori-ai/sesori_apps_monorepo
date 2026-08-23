import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
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
class const NotificationSettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationPreferencesCubit(
        service: getIt<NotificationPreferencesService>(),
      ),
      child: const _NotificationSettingsBody(),
    );
  }
}

class const _NotificationSettingsBody() extends StatelessWidget {
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
              NotificationPreferencesLoading() => Padding(
                padding: const EdgeInsetsDirectional.only(top: PregoSpacing.x4l),
                child: Center(child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)),
              ),
              NotificationPreferencesAccountUnavailable() => const _NotificationPreferencesUnavailable(),
              NotificationPreferencesLoadFailed() => const _NotificationPreferencesFailure(),
              NotificationPreferencesLoaded(:final preferences, :final updatingCategories) => Column(
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
                          updatingCategories: updatingCategories,
                        ),
                        _NotificationToggleRow(
                          category: NotificationCategory.sessionMessage,
                          title: loc.notificationCategorySessionMessage,
                          subtitle: loc.notificationCategorySessionMessageDescription,
                          preferences: preferences,
                          updatingCategories: updatingCategories,
                        ),
                        _NotificationToggleRow(
                          category: NotificationCategory.connectionStatus,
                          title: loc.notificationCategoryConnectionStatus,
                          subtitle: loc.notificationCategoryConnectionStatusDescription,
                          preferences: preferences,
                          updatingCategories: updatingCategories,
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
                          updatingCategories: updatingCategories,
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

class const _NotificationPreferencesUnavailable() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.info_circle,
          title: Text(context.loc.notificationPreferencesUnavailableTitle),
          subtitle: Text(context.loc.notificationPreferencesUnavailableDescription),
        ),
      ],
    );
  }
}

class const _NotificationPreferencesFailure() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(context.loc.notificationPreferencesLoadFailedTitle),
          subtitle: Text(context.loc.notificationPreferencesLoadFailedDescription),
          trailing: PregoButtonsSolid(
            key: const Key("notification_preferences_retry"),
            label: context.loc.notificationPreferencesRetry,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.sm,
            onPressed: context.read<NotificationPreferencesCubit>().retry,
          ),
        ),
      ],
    );
  }
}

class const _NotificationToggleRow({
  required final NotificationCategory category,
  required final String title,
  required final String? subtitle,
  required final Map<NotificationCategory, bool> preferences,
  required final Set<NotificationCategory> updatingCategories,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final enabled = preferences[category] ?? true;
    final isUpdating = updatingCategories.contains(category);
    void toggle({required bool enabled}) {
      context.read<NotificationPreferencesCubit>().toggle(category, enabled: enabled);
    }

    final trailing = isUpdating
        ? Semantics(
            label: context.loc.notificationPreferenceUpdating,
            child: SizedBox(
              key: ValueKey("notification_preference_loading_${category.name}"),
              width: context.prego.spacing.spacing16,
              child: Center(
                child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
              ),
            ),
          )
        : PregoSwitch(
            key: ValueKey("notification_preference_switch_${category.name}"),
            value: enabled,
            onChanged: (enabled) => toggle(enabled: enabled),
          );

    // Merged so assistive tech announces one labelled toggle (title,
    // description, state) instead of an unlabelled switch beside plain text.
    return MergeSemantics(
      child: PregoGroupedRow(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing,
        onTap: isUpdating ? null : () => toggle(enabled: !enabled),
      ),
    );
  }
}
