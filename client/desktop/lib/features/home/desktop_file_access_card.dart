import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

/// Optional local-computer guidance; never blocks the home pane or remote work.
class const DesktopFileAccessCard({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!context.select((FileAccessCubit cubit) => cubit.state.showPrompt)) return const SizedBox.shrink();
    final cubit = context.read<FileAccessCubit>();
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.xl),
      child: DecoratedBox(
        key: const Key("desktop-file-access-card"),
        decoration: BoxDecoration(
          color: context.prego.colors.bgSurface2,
          borderRadius: BorderRadius.circular(PregoRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.desktopFileAccessTitle, style: context.prego.textTheme.textMd.bold),
              const SizedBox(height: PregoSpacing.md),
              Text(loc.desktopFileAccessDescription, style: context.prego.textTheme.textSm.regular),
              const SizedBox(height: PregoSpacing.md),
              Wrap(
                spacing: PregoSpacing.sm,
                children: [
                  TextButton(onPressed: cubit.openSystemSettings, child: Text(loc.desktopFileAccessOpenSettings)),
                  TextButton(onPressed: cubit.dismiss, child: Text(loc.desktopFileAccessNotNow)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
