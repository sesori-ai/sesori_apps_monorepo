import "package:flutter/material.dart";

import "../../../core/extensions/build_context_x.dart";

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
