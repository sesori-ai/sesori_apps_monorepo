import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/external_link.dart";

/// Manual distribution guidance; this surface never installs or quits the app.
class const DesktopUpdateSection({super.key, required final DesktopUpdateDestination destination})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (title, subtitle, onTap) = switch (destination) {
      DesktopManualDownload(:final uri) => (
        "View downloads",
        "See published releases for this build. Quit Sesori before replacing the app, then reopen it manually. "
            "Closing the window is not Quit.",
        () => unawaited(openDesktopExternalLink(url: uri, mode: UrlLaunchMode.externalApp)),
      ),
      DesktopPackageManagerUpdate() => (
        "Package-managed updates",
        "Use your distribution's signed package repository when available. Quit Sesori before upgrading.",
        null,
      ),
      DesktopDevelopmentUpdate() => (
        "Development build",
        "Update from your source checkout. Packaged download selection is unavailable for this build.",
        null,
      ),
    };
    return SettingsSection(
      title: "Desktop updates",
      child: PregoGroupedRows(
        children: [
          PregoGroupedRow(
            icon: TablerRegular.download,
            title: Text(title),
            subtitle: Text(subtitle),
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
