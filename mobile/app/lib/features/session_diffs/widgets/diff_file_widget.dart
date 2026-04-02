import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/diff_file_view_model.dart";
import "../utils/diff_theme.dart";

/// Renders a single file diff header with file name, +/- stats,
/// status badge, and expand/collapse chevron.
class DiffFileWidget extends StatelessWidget {
  final DiffFileViewModel viewModel;
  final bool isExpanded;
  final VoidCallback onToggle;

  const DiffFileWidget({
    super.key,
    required this.viewModel,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: _buildHeader(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final vm = viewModel;
    final theme = DiffTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.fileHeaderBg,
        border: Border(
          bottom: BorderSide(color: theme.fileHeaderBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // File name
          Expanded(
            child: Text(
              vm.fileName,
              style: const TextStyle(
                fontFamily: "monospace",
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // +N stats
          Text(
            "+${vm.additions}",
            style: TextStyle(
              fontFamily: "monospace",
              fontSize: 12,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 4),
          // -M stats
          Text(
            "-${vm.deletions}",
            style: TextStyle(
              fontFamily: "monospace",
              fontSize: 12,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          _buildStatusBadge(vm.status),
          const SizedBox(width: 4),
          // Chevron
          Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: theme.chevronColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(FileDiffStatus? status) {
    final (label, color) = switch (status) {
      FileDiffStatus.added => ("A", Colors.green),
      FileDiffStatus.deleted => ("D", Colors.red),
      FileDiffStatus.modified || null => ("M", Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
