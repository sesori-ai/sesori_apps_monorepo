import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "widgets/chat_input_mode_picker.dart";

/// Default composer preference presentation; the product shell owns navigation.
class const DefaultInputSettingsView({
  super.key,
  required final VoidCallback onBack,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return PregoGlassScaffold(
      title: loc.settingsDefaultInputTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      onBack: onBack,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          onPressed: onClose,
        ),
      ],
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 25),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      loc.settingsDefaultInputDescription,
                      style: context.prego.textTheme.textSm.regular.copyWith(
                        color: context.prego.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PregoSpacing.xl),
                const ChatInputModePicker(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
