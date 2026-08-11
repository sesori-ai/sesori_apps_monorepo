import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/chat_input_mode_picker.dart";

/// Chooses which input method the session composer presents by default.
class DefaultInputSettingsScreen extends StatelessWidget {
  const DefaultInputSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return PregoGlassScaffold(
      title: loc.settingsDefaultInputTitle,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  PregoSpacing.xl,
                  PregoSpacing.sm,
                  PregoSpacing.xl,
                  0,
                ),
                child: Text(
                  loc.settingsDefaultInputDescription,
                  style: context.prego.textTheme.textSm.regular.copyWith(
                    color: context.prego.colors.textPrimary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: PregoSpacing.xl,
                  vertical: PregoSpacing.xl,
                ),
                child: ChatInputModePicker(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
