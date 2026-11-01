import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

const Duration _selectionFadeDuration = Duration(milliseconds: 150);

/// Picks the engine that transcribes dictation; the product shell owns navigation.
/// Temporary, for comparing the engines. Not gated to internal builds, so decide before the next public release.
class const VoiceEngineSettingsView({
  super.key,
  required final VoidCallback onBack,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<VoiceEngineCubit>();

    return PregoGlassScaffold(
      title: loc.settingsVoiceEngineTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      onBack: onBack,
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            PregoSpacing.xl,
            0,
            PregoSpacing.xl,
            PregoSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.settingsVoiceEngineDescription,
                  style: context.prego.textTheme.textSm.regular.copyWith(
                    color: context.prego.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: PregoSpacing.xl),
                PregoGroupedRows(
                  children: [
                    for (final engine in VoiceEngine.values)
                      _VoiceEngineOption(
                        title: switch (engine) {
                          VoiceEngine.device => loc.settingsVoiceEngineDevice,
                          VoiceEngine.remote => loc.settingsVoiceEngineRemote,
                        },
                        subtitle: switch (engine) {
                          VoiceEngine.device => loc.settingsVoiceEngineDeviceDescription,
                          VoiceEngine.remote => loc.settingsVoiceEngineRemoteDescription,
                        },
                        isSelected: cubit.state == engine,
                        onTap: () => cubit.select(engine: engine),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class const _VoiceEngineOption({
  required final String title,
  required final String subtitle,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        child: PregoGroupedRow(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: AnimatedOpacity(
            opacity: isSelected ? 1 : 0,
            duration: _selectionFadeDuration,
            child: Icon(TablerRegular.check, color: context.prego.colors.textPrimary),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
