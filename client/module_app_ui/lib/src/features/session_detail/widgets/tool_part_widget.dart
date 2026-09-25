import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "../../../l10n/app_localizations.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "attachment_collection_widget.dart";
import "transcript_disclosure.dart";

class const ToolPartWidget({super.key, required final MessagePartTool part}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final state = part.state;
    final hasDetails = state.shellCommand != null || state.output != null || state.error != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (hasDetails)
            TranscriptDisclosure(
              toggleKey: const ValueKey("shellTool.toggle"),
              headerBuilder: ({required expanded}) => _ToolHeader(part: part),
              panel: _ToolPanel(part: part),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: prego.spacing.sm),
              child: _ToolHeader(part: part),
            ),
          if (state.attachments.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(top: prego.spacing.xs),
              child: AttachmentCollectionWidget(
                sessionId: part.sessionID,
                attachments: state.attachments,
              ),
            ),
        ],
      ),
    );
  }

  static String _toolName({required AppLocalizations loc, required MessagePartTool part}) =>
      part.tool.isEmpty ? loc.sessionDetailToolUnknown : part.tool;
}

/// The tool's one line. A finished tool shows only what it did; a failure keeps
/// one signal: its icon, or a shell's red line.
class const _ToolHeader({required final MessagePartTool part}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = part.state;
    final status = state.status;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final command = state.shellCommand;

    if (command != null) {
      final verb = switch (status) {
        ToolStatus.completed => loc.sessionDetailCommandRan,
        ToolStatus.pending => loc.sessionDetailToolPending,
        ToolStatus.running => loc.sessionDetailToolRunning,
        ToolStatus.error => loc.sessionDetailToolError,
        ToolStatus.cancelled => loc.sessionDetailToolCancelled,
        ToolStatus.unknown => loc.sessionDetailToolUnknown,
      };
      final rowStyle = status == ToolStatus.error ? style.copyWith(color: prego.colors.textErrorPrimary) : style;
      return Row(
        children: [
          Icon(TablerRegular.terminal_2, size: PregoIconSize.sm, color: rowStyle.color),
          SizedBox(width: prego.spacing.md),
          Expanded(
            child: _LiveLabel(
              live: _isLive(status: status),
              label: Text.rich(
                TextSpan(
                  text: "$verb ",
                  children: [
                    TextSpan(
                      text: "\$ $command",
                      style: rowStyle.copyWith(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
                style: rowStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              semanticLabel: "$verb \$ $command",
            ),
          ),
        ],
      );
    }

    final label = [ToolPartWidget._toolName(loc: loc, part: part), ?state.title].join(" ");
    return Row(
      children: [
        _statusIcon(status: status, prego: prego),
        SizedBox(width: prego.spacing.md),
        Expanded(
          child: _LiveLabel(
            live: _isLive(status: status),
            label: Text(label, style: style, maxLines: 1, overflow: .ellipsis),
            semanticLabel: label,
          ),
        ),
      ],
    );
  }

  static bool _isLive({required ToolStatus status}) => status == ToolStatus.pending || status == ToolStatus.running;

  static Widget _statusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    ToolStatus.pending || ToolStatus.running || ToolStatus.completed => Icon(
      TablerRegular.tool,
      size: PregoIconSize.sm,
      color: prego.colors.textTertiary,
    ),
    ToolStatus.error => Icon(TablerSolid.alert_circle, size: PregoIconSize.sm, color: prego.colors.fgErrorPrimary),
    ToolStatus.cancelled => Icon(
      TablerSolid.circle_x,
      size: PregoIconSize.sm,
      color: prego.colors.textSecondary,
    ),
    ToolStatus.unknown => Icon(
      TablerRegular.circle,
      size: PregoIconSize.sm,
      color: prego.colors.borderPrimary,
    ),
  };
}

/// The tool's details: a shell's command, then the output and error, in one
/// bounded viewport that scrolls on both axes.
class const _ToolPanel({required final MessagePartTool part}) extends StatefulWidget {
  @override
  State<_ToolPanel> createState() => _ToolPanelState();
}

class _ToolPanelState() extends State<_ToolPanel> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = widget.part.state;
    final command = state.shellCommand;
    final output = state.output;
    final error = state.error;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final blocks = <TextSpan>[
      if (command != null) TextSpan(text: "\$ $command"),
      if (output != null) TextSpan(text: output),
      if (error != null)
        TextSpan(
          text: error,
          style: TextStyle(color: prego.colors.textErrorPrimary),
        ),
    ];
    final transcript = blocks.map((block) => block.text).join("\n\n");

    // The whole panel scrolls the text sideways, not only the text, so a swipe
    // anywhere on it never reaches the transcript's own swipe.
    return GestureDetector(
      supportedDevices: ScrollConfiguration.of(context).dragDevices,
      onHorizontalDragUpdate: (details) {
        if (!_horizontalController.hasClients) return;
        final position = _horizontalController.position;
        position.jumpTo(
          (position.pixels - details.delta.dx).clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(prego.spacing.md),
        decoration: BoxDecoration(
          color: prego.colors.bgSurface4,
          borderRadius: BorderRadius.circular(PregoRadius.xs),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    command != null ? loc.sessionDetailShell : ToolPartWidget._toolName(loc: loc, part: widget.part),
                    style: style,
                  ),
                ),
                PregoCopyIconButton(
                  onCopy: () => copyTextToClipboard(
                    text: transcript,
                    operation: command != null ? "shell transcript" : "tool output",
                  ),
                  tooltip: loc.sessionDetailCopy,
                ),
              ],
            ),
            // Fits a short transcript; a long one scrolls within this cap.
            ConstrainedBox(
              key: const ValueKey("shellTool.viewport"),
              constraints: const BoxConstraints(maxHeight: 144),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                // System safe-area insets belong to the screen, not this
                // embedded viewport's scrollbar tracks.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  removeLeft: true,
                  removeRight: true,
                  child: RawScrollbar(
                    controller: _horizontalController,
                    scrollbarOrientation: ScrollbarOrientation.bottom,
                    thumbVisibility: true,
                    interactive: true,
                    thumbColor: prego.colors.borderPrimary,
                    thickness: 5,
                    radius: Radius.circular(prego.radius.full),
                    notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                    child: RawScrollbar(
                      controller: _verticalController,
                      scrollbarOrientation: ScrollbarOrientation.right,
                      thumbVisibility: true,
                      interactive: true,
                      thumbColor: prego.colors.borderPrimary,
                      thickness: 5,
                      radius: Radius.circular(prego.radius.full),
                      notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        primary: false,
                        child: SingleChildScrollView(
                          controller: _horizontalController,
                          scrollDirection: Axis.horizontal,
                          primary: false,
                          padding: EdgeInsetsDirectional.only(end: prego.spacing.lg, bottom: prego.spacing.lg),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                for (final (index, block) in blocks.indexed) ...[
                                  if (index > 0) const TextSpan(text: "\n\n"),
                                  block,
                                ],
                              ],
                            ),
                            style: prego.textTheme.code.copyWith(color: style.color),
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A running step's label shimmers in place of a spinner; reduced motion keeps
/// it still.
class const _LiveLabel({required final bool live, required final Widget label, required final String semanticLabel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!live) return label;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: PregoShimmer(appearDelay: Duration.zero, semanticLabel: semanticLabel, child: label),
    );
  }
}
