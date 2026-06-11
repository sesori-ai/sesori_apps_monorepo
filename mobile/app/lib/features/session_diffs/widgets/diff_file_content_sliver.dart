import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "../models/diff_file_view_model.dart";
import "diff_hunk_widget.dart";
import "diff_line_widget.dart";

/// Sliver that renders the body of one expanded file diff: a lazy list of
/// its hunk headers and lines, or an italic placeholder when the diff was
/// skipped (binary file, too large, or unreadable).
class DiffFileContentSliver extends StatelessWidget {
  final DiffFileViewModel viewModel;

  const DiffFileContentSliver({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.skipReason case final skipReason?) {
      return SliverToBoxAdapter(child: _SkippedPlaceholder(reason: skipReason));
    }
    final childCount = viewModel.hunks.fold<int>(0, (sum, h) => sum + 1 + h.lines.length);
    return SliverList.builder(
      itemCount: childCount,
      itemBuilder: (context, index) {
        var remaining = index;
        for (final hunk in viewModel.hunks) {
          if (remaining == 0) return DiffHunkWidget(viewModel: hunk);
          remaining--;
          if (remaining < hunk.lines.length) {
            return DiffLineWidget(viewModel: hunk.lines[remaining]);
          }
          remaining -= hunk.lines.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SkippedPlaceholder extends StatelessWidget {
  final FileDiffSkipReason reason;

  const _SkippedPlaceholder({required this.reason});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final message = switch (reason) {
      FileDiffSkipReason.binary => loc.diffBinaryFileChanged,
      FileDiffSkipReason.tooLarge => loc.diffFileTooLarge,
      FileDiffSkipReason.readError => loc.diffCouldNotReadFile,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
