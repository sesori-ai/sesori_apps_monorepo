import "package:material_ui/material_ui.dart";

import "package:sesori_app_ui/sesori_app_ui.dart";

/// Centered error message with a retry button, shown when the diff fails
/// to load or when diff view-model computation fails.
class const DiffErrorView({super.key, required final Object error, required final VoidCallback onRetry})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.loc.diffErrorPrefix(error.toString())),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(context.loc.diffRetry),
          ),
        ],
      ),
    );
  }
}
