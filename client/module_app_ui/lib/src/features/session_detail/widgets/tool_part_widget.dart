import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "../../../extensions/text_style_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "attachment_collection_widget.dart";

class const ToolPartWidget({super.key, required final MessagePartTool part}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = part.state;
    final toolName = part.tool.isEmpty ? loc.sessionDetailToolUnknown : part.tool;
    final detail = state.title;
    final status = state.status;
    final output = status == ToolStatus.completed ? state.output : null;
    final errorText = status == ToolStatus.error ? state.error : null;
    final command = state.shellCommand;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (command != null)
            _ShellToolPreview(command: command, state: state)
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: prego.spacing.sm),
              child: Row(
                children: [
                  _statusIcon(status: status, prego: prego),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: toolName,
                        children: [
                          if (detail != null)
                            TextSpan(
                              text: " $detail",
                              style: prego.textTheme.textSm.regular.copyWith(
                                color: prego.colors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      style: prego.textTheme.textSm.regular.copyWith(
                        color: prego.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  Text(
                    _statusLabel(loc: loc, status: status),
                    style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
                  ),
                ],
              ),
            ),
          if (command == null && output != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
              child: _ToolOutputBlock(output: output),
            ),
          if (command == null && errorText != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
              child: Text(
                errorText,
                style: prego.textTheme.textXs.regular.copyWith(
                  color: prego.colors.fgErrorPrimary,
                ),
                maxLines: 4,
                overflow: .ellipsis,
              ),
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

  static Widget _statusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    ToolStatus.pending || ToolStatus.running => const SizedBox(
      width: 16,
      height: 16,
      child: PregoActivityIndicator(color: null),
    ),
    ToolStatus.completed => Icon(
      TablerRegular.tool,
      size: 16,
      color: prego.colors.textTertiary,
    ),
    ToolStatus.error => Icon(Icons.error, size: 16, color: prego.colors.fgErrorPrimary),
    ToolStatus.cancelled => Icon(
      Icons.cancel,
      size: 16,
      color: prego.colors.textSecondary,
    ),
    ToolStatus.unknown => Icon(
      Icons.circle_outlined,
      size: 16,
      color: prego.colors.borderPrimary,
    ),
  };

  static String _statusLabel({required AppLocalizations loc, required ToolStatus status}) => switch (status) {
    ToolStatus.pending => loc.sessionDetailToolPending,
    ToolStatus.running => loc.sessionDetailToolRunning,
    ToolStatus.completed => loc.sessionDetailToolCompleted,
    ToolStatus.error => loc.sessionDetailToolError,
    ToolStatus.cancelled => loc.sessionDetailToolCancelled,
    ToolStatus.unknown => loc.sessionDetailToolUnknown,
  };
}

/// A disclosure for an authoritative shell command, never inferred from a tool name.
class const _ShellToolPreview({required final String command, required final ToolState state}) extends StatefulWidget {
  @override
  State<_ShellToolPreview> createState() => _ShellToolPreviewState();
}

class _ShellToolPreviewState() extends State<_ShellToolPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _disclosure = AnimationController(vsync: this, duration: _disclosureDuration);
  late final CurvedAnimation _panelSize = CurvedAnimation(parent: _disclosure, curve: Curves.easeOut);
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  /// The user's choice. The panel itself stays mounted until it has closed.
  bool get _expanded => _disclosure.isForwardOrCompleted;

  @override
  void initState() {
    super.initState();
    _disclosure.addStatusListener(_onDisclosureStatus);
  }

  @override
  void dispose() {
    _panelSize.dispose();
    _disclosure.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (context.isReducedMotion) {
      _disclosure.value = _expanded ? 0 : 1;
    } else if (_expanded) {
      _disclosure.reverse();
    } else {
      _disclosure.forward();
    }
    setState(() {});
  }

  void _onDisclosureStatus(AnimationStatus status) {
    if (status.isCompleted) {
      // Only the user's own expand completes the disclosure, so a later resize
      // of the open panel never scrolls the transcript.
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    } else if (status.isDismissed) {
      // Drops the closed panel, so its copy buttons do not stay reachable at
      // zero height.
      setState(() {});
    }
  }

  void _reveal() {
    if (!mounted) return;
    // The transcript is reversed. Growing a historical row otherwise pushes
    // its header above the viewport (and behind the floating navigation).
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: context.isReducedMotion ? Duration.zero : _disclosureDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = widget.state;
    final output = state.output;
    final error = state.error;
    final statusLabel = ToolPartWidget._statusLabel(loc: loc, status: state.status);
    final rowLabel = state.status == ToolStatus.completed ? loc.sessionDetailCommandRan : statusLabel;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final rowStyle = state.status == ToolStatus.error ? style.copyWith(color: prego.colors.textErrorPrimary) : style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _expanded,
          child: TextButton(
            key: const ValueKey("shellTool.toggle"),
            onPressed: _toggle,
            style: TextButton.styleFrom(
              foregroundColor: prego.colors.textSecondary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: AlignmentDirectional.centerStart,
            ),
            child: Row(
              children: [
                if (state.status == ToolStatus.pending || state.status == ToolStatus.running)
                  ToolPartWidget._statusIcon(status: state.status, prego: prego)
                else
                  Icon(TablerRegular.terminal_2, size: 16, color: rowStyle.color),
                SizedBox(width: prego.spacing.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: "$rowLabel ",
                      children: [
                        TextSpan(
                          text: "\$ ${widget.command}",
                          style: rowStyle.copyWith(decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                    style: rowStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_disclosure.isDismissed)
          SizeTransition(
            sizeFactor: _panelSize,
            alignment: AlignmentDirectional.topStart,
            child: Container(
              key: const ValueKey("shellTool.panel"),
              width: double.infinity,
              padding: EdgeInsets.all(prego.spacing.md),
              decoration: BoxDecoration(
                color: prego.colors.bgSurface2,
                borderRadius: BorderRadius.circular(prego.radius.xl),
                border: Border.all(color: prego.colors.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(loc.sessionDetailShell, style: style)),
                      PregoCopyIconButton(
                        onCopy: () => copyTextToClipboard(text: widget.command, operation: "shell command"),
                        tooltip: loc.sessionDetailCopyCommand,
                      ),
                    ],
                  ),
                  SizedBox(
                    key: const ValueKey("shellTool.viewport"),
                    height: 144,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                      // System safe-area insets belong to the screen, not this
                      // embedded terminal's scrollbar tracks.
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
                                    text: "\$ ${widget.command}",
                                    children: [
                                      if (output != null) TextSpan(text: "\n\n$output"),
                                      if (error != null)
                                        TextSpan(
                                          text: "\n\n$error",
                                          style: TextStyle(color: prego.colors.textErrorPrimary),
                                        ),
                                    ],
                                  ),
                                  style: style.monospace,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: output == null ? WrapAlignment.end : WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: prego.spacing.md,
                      children: [
                        if (output != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text(loc.sessionDetailShellOutput, style: style)),
                              PregoCopyIconButton(
                                onCopy: () => copyTextToClipboard(text: output, operation: "tool output"),
                                tooltip: loc.sessionDetailCopyOutput,
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.status == ToolStatus.completed)
                              Icon(TablerRegular.check, size: 16, color: prego.colors.textSecondary)
                            else
                              ToolPartWidget._statusIcon(status: state.status, prego: prego),
                            SizedBox(width: prego.spacing.xs),
                            Flexible(child: Text(statusLabel, style: style)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Tool output panel: collapsed to 8 lines by default with a one-tap copy
/// button, expandable to the full (previously hard-capped at 500 chars)
/// output. Kept collapsed by default so large outputs don't grow the list
/// or jank while streaming.
class const _ToolOutputBlock({required final String output}) extends StatefulWidget {
  @override
  State<_ToolOutputBlock> createState() => _ToolOutputBlockState();
}

class _ToolOutputBlockState() extends State<_ToolOutputBlock> {
  /// Collapsed line budget; mirrors the previous fixed `maxLines: 8`.
  static const _collapsedMaxLines = 8;

  bool _expanded = false;

  /// Horizontal space reserved at the text's trailing edge for the overlaid
  /// copy button, so wrapped text never runs under it and overflow is measured
  /// against the same width the text actually lays out in.
  static const _copyButtonReserve = 32.0;

  /// Inputs of the last overflow measurement. The parent list rebuilds every
  /// visible row on each streaming flush, so without this cache every rebuild
  /// would lay out a throwaway [TextPainter] per visible tool output.
  String? _measuredOutput;
  double? _measuredWidth;
  TextScaler? _measuredScaler;
  TextStyle? _measuredStyle;
  TextDirection? _measuredDirection;
  bool _isExpandable = false;

  bool _measureIsExpandable({
    required BuildContext context,
    required String output,
    required double textWidth,
    required TextStyle monoStyle,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    if (output == _measuredOutput &&
        textWidth == _measuredWidth &&
        textScaler == _measuredScaler &&
        monoStyle == _measuredStyle &&
        textDirection == _measuredDirection) {
      return _isExpandable;
    }
    final painter = TextPainter(
      text: TextSpan(text: output, style: monoStyle),
      maxLines: _collapsedMaxLines,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: textWidth);
    _measuredOutput = output;
    _measuredWidth = textWidth;
    _measuredScaler = textScaler;
    _measuredStyle = monoStyle;
    _measuredDirection = textDirection;
    _isExpandable = painter.didExceedMaxLines;
    painter.dispose();
    return _isExpandable;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final output = widget.output;
    final monoStyle = prego.textTheme.textXs.regular.copyWith(fontSize: 11).monospace;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: prego.colors.bgQuaternary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Measure actual overflow against the collapsed budget at the real
          // text width (accounts for soft-wrapped long lines, not just
          // explicit newlines). maxLines bounds the layout cost.
          final textWidth = constraints.maxWidth - _copyButtonReserve;
          final isExpandable = _measureIsExpandable(
            context: context,
            output: output,
            textWidth: textWidth,
            monoStyle: monoStyle,
          );

          final block = Column(
            crossAxisAlignment: .start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      // Reserve trailing room for the overlaid copy button.
                      padding: const EdgeInsetsDirectional.only(end: _copyButtonReserve),
                      child: Text(
                        output,
                        style: monoStyle,
                        maxLines: _expanded ? null : _collapsedMaxLines,
                        overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: PregoCopyIconButton(
                      onCopy: () => copyTextToClipboard(text: output, operation: "tool output"),
                      tooltip: loc.sessionDetailCopy,
                      iconSize: 14,
                    ),
                  ),
                ],
              ),
              if (isExpandable)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      _expanded ? loc.sessionDetailShowLess : loc.sessionDetailShowMore,
                      style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.bgBrandSolid),
                    ),
                  ),
                ),
            ],
          );
          return _AnimatedDisclosure(child: block);
        },
      ),
    );
  }
}

const _disclosureDuration = Duration(milliseconds: 200);

/// Eases long tool output open and shut behind Show more, growing down from its
/// top edge.
class const _AnimatedDisclosure({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // No wrapper at all under reduced motion: a zero-duration AnimatedSize
    // re-dirties itself inside its own layout pass.
    if (context.isReducedMotion) return child;
    return AnimatedSize(
      duration: _disclosureDuration,
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }
}
