part of "../project_list_screen.dart";

/// Shown when loading projects fails while the bridge is connected.
class _ErrorView extends StatelessWidget {
  final ApiError error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final zyra = context.zyra;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: zyra.colors.fgErrorPrimary,
            ),
            const SizedBox(height: 16),
            Text(
              loc.projectListErrorTitle,
              style: zyra.textTheme.textMd.bold,
            ),
            const SizedBox(height: 8),
            Text(
              error.localizedMessage(loc),
              textAlign: .center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.projectListRetry),
            ),
          ],
        ),
      ),
    );
  }
}
