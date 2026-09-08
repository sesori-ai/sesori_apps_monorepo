import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";

/// Mobile navigation for the shared default input preference page.
class const DefaultInputSettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultInputSettingsView(
      onBack: () => context.pop(),
      onClose: () {
        // This page is pushed from Settings; close both pages to its opener.
        context.pop();
        context.pop();
      },
    );
  }
}
