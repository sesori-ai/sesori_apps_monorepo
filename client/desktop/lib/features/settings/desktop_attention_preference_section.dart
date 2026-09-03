import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

/// Desktop-only attention preference rendered inside the shared settings view.
class const DesktopAttentionPreferenceSection({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final preference = context.watch<DesktopAttentionPreferenceCubit>().state;

    void update({required bool enabled}) {
      unawaited(context.read<DesktopAttentionPreferenceCubit>().setEnabled(enabled: enabled));
    }

    return SettingsSection(
      title: context.loc.settingsNotificationsTitle,
      child: PregoGroupedRows(
        children: [
          PregoGroupedRow(
            icon: TablerRegular.bell,
            title: Text(context.loc.notificationCategoryAiInteraction),
            subtitle: Text(context.loc.notificationCategoryAiInteractionDescription),
            trailing: PregoSwitch(
              value: preference.isEnabled,
              onChanged: (enabled) => update(enabled: enabled),
            ),
            onTap: () => update(enabled: !preference.isEnabled),
          ),
        ],
      ),
    );
  }
}
