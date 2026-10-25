import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";

/// Mobile-shell composition for the shared projects view. The signed-in
/// session scope provides the project list and the folder browser's services.
class const ProjectsSettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ProjectsSettingsView(
    chrome: SettingsPageOwnBar(
      title: context.loc.settingsProjectsTitle,
      connectionBanner: ConnectionBanner.maybeFor(context),
    ),
  );
}
