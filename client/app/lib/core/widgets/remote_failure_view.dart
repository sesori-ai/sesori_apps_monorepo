import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/remote_failure_x.dart";

class const RemoteFailureView({
  required final RemoteFailureReason reason,
  required final String title,
  required final String retryLabel,
  required final VoidCallback onRetry,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: prego.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(title, style: prego.textTheme.textMd.bold),
            const SizedBox(height: 8),
            Text(reason.localizedMessage(context.loc), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
