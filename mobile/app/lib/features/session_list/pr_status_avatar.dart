import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A [CircleAvatar] showing a pull request icon whose color reflects the PR's
/// current state and mergeable status.
///
/// Color mapping:
/// - Open + mergeable → green
/// - Open + conflicting → red
/// - Open + unknown → amber
/// - Merged → purple
/// - Closed / unknown → grey
class PrStatusAvatar extends StatelessWidget {
  final PullRequestInfo pr;

  const PrStatusAvatar({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final (bgColor, fgColor) = _colors(context);
    return CircleAvatar(
      backgroundColor: bgColor,
      child: Icon(Icons.merge_type, color: fgColor),
    );
  }

  (Color bg, Color fg) _colors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (pr.state) {
      PrState.merged => (Colors.purple.shade50, Colors.purple),
      PrState.closed => (scheme.surfaceContainerHighest, scheme.outline),
      PrState.open => switch (pr.mergeableStatus) {
        PrMergeableStatus.mergeable => (Colors.green.shade50, Colors.green.shade700),
        PrMergeableStatus.conflicting => (scheme.errorContainer, scheme.error),
        PrMergeableStatus.unknown => (Colors.amber.shade50, Colors.amber.shade800),
      },
      PrState.unknown => (scheme.surfaceContainerHighest, scheme.outline),
    };
  }
}
