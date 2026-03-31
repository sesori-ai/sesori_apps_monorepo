import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../models/diff_file_view_model.dart";
import "diff_hunk_widget.dart";

/// Renders a single file diff: a tappable header with file name, +/- stats,
/// status badge, and expand/collapse chevron. When expanded, shows either the
/// diff hunks or a skipped-file placeholder.
class DiffFileWidget extends StatefulWidget {
  final DiffFileViewModel viewModel;

  const DiffFileWidget({super.key, required this.viewModel});

  @override
  State<DiffFileWidget> createState() => _DiffFileWidgetState();
}

class _DiffFileWidgetState extends State<DiffFileWidget> {
  late bool _isExpanded;

  /// Light header background.
  static const _headerBg = Color(0xFFF8F8F8);
  static const _headerBorder = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.viewModel.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row — tappable to toggle expand/collapse
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: _buildHeader(),
        ),
        // Body — visible when expanded
        if (_isExpanded)
          widget.viewModel.skipReason != null
              ? _buildSkippedPlaceholder(widget.viewModel.skipReason!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.viewModel.hunks.map((h) => DiffHunkWidget(viewModel: h)).toList(),
                ),
      ],
    );
  }

  Widget _buildHeader() {
    final vm = widget.viewModel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(
          bottom: BorderSide(color: _headerBorder, width: 0.5),
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
                fontSize: 12,
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
              fontSize: 11,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 4),
          // -M stats
          Text(
            "-${vm.deletions}",
            style: TextStyle(
              fontFamily: "monospace",
              fontSize: 11,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          _buildStatusBadge(vm.status),
          const SizedBox(width: 4),
          // Chevron
          Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: Colors.grey.shade600,
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSkippedPlaceholder(FileDiffSkipReason reason) {
    final message = switch (reason) {
      FileDiffSkipReason.binary => "Binary file changed",
      FileDiffSkipReason.tooLarge => "File diff too large to display",
      FileDiffSkipReason.readError => "Could not read file",
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
