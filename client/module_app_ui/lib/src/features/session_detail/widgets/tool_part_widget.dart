import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "../../../l10n/app_localizations.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "attachment_collection_widget.dart";
import "transcript_disclosure.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";

class const ToolPartWidget({super.key, required final MessagePartTool part}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final state = part.state;
    final hasDetails =
        state.shellCommand != null ||
        switch (state) {
          ToolStateFull(:final output, :final error) => output != null || error != null,
          // The bridge summarizes only tools that have output or error.
          ToolStateSummary() => true,
        };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TranscriptStepRow.stepGap),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (hasDetails) _disclosure(context: context) else _ToolHeader(part: part),
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

  /// A full part carries its own output. A summary's output is fetched when
  /// its panel opens, and the disclosure eases between the loading, failed
  /// and output heights.
  Widget _disclosure({required BuildContext context}) {
    final output = switch (part.state) {
      ToolStateFull(:final output, :final error) => ToolOutputLoaded(output: output, error: error),
      ToolStateSummary() =>
        context.select<SessionDetailCubit, ToolOutputFetch?>(
              (cubit) => switch (cubit.state) {
                SessionDetailLoaded(:final toolOutputs) => toolOutputs[(messageId: part.messageID, partId: part.id)],
                SessionDetailLoading() || SessionDetailHarnessUnavailable() || SessionDetailFailed() => null,
              },
            ) ??
            const ToolOutputLoading(),
    };
    return TranscriptDisclosure(
      toggleKey: const ValueKey("shellTool.toggle"),
      headerBuilder: ({required expanded}) => _ToolHeader(part: part),
      // Each change between loading, failing and the output eases the panel
      // to its new height.
      panelContentKey: ValueKey(switch (output) {
        ToolOutputLoading() => _PanelContent.loading,
        ToolOutputFailed() => _PanelContent.failed,
        ToolOutputLoaded() => _PanelContent.output,
      }),
      panel: _ToolPanel(
        part: part,
        output: output,
        fetchOutput: switch (part.state) {
          ToolStateFull() => null,
          ToolStateSummary() => () => unawaited(
            context.read<SessionDetailCubit>().fetchToolOutput(messageId: part.messageID, partId: part.id),
          ),
        },
      ),
    );
  }

  /// The tool's name as its row, panel and live label show it.
  static String toolName({required AppLocalizations loc, required MessagePartTool part}) =>
      TranscriptStepRow.capitalize(label: part.tool.isEmpty ? loc.sessionDetailToolUnknown : part.tool);
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
    final command = state.shellCommand;
    final title = state.title;
    final live = _isLive(status: status);

    if (command != null) {
      final verb = switch (status) {
        ToolStatus.completed => loc.sessionDetailCommandRan,
        ToolStatus.pending => loc.sessionDetailToolPending,
        ToolStatus.running => loc.sessionDetailToolRunning,
        ToolStatus.error => loc.sessionDetailToolError,
        ToolStatus.cancelled => loc.sessionDetailToolCancelled,
        ToolStatus.unknown => loc.sessionDetailToolUnknown,
      };
      final color = status == ToolStatus.error ? prego.colors.textErrorPrimary : prego.colors.textSecondary;
      return TranscriptStepRow(
        leading: live
            ? const TranscriptLiveSparkle()
            : Icon(TablerRegular.terminal_2, size: PregoIconSize.sm, color: color),
        label: verb,
        detail: TextSpan(
          text: "\$ $command",
          style: const TextStyle(decoration: TextDecoration.underline),
        ),
        live: live,
        color: color,
        trailing: null,
      );
    }

    return TranscriptStepRow(
      leading: live ? const TranscriptLiveSparkle() : _statusIcon(status: status, prego: prego),
      label: ToolPartWidget.toolName(loc: loc, part: part),
      detail: title == null ? null : TextSpan(text: title),
      live: live,
      color: null,
      trailing: null,
    );
  }

  static bool _isLive({required ToolStatus status}) => status == ToolStatus.pending || status == ToolStatus.running;

  static Widget _statusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    // A live tool leads with the sparkle instead.
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

/// What an open tool panel shows below its title and command.
enum _PanelContent() {
  loading,
  failed,
  output,
}

/// The tool's details: a shell's command, then the output and error, in one
/// bounded viewport that scrolls on both axes. Until a summary's output
/// arrives, a fixed-height row below the command stands in for it.
class const _ToolPanel({
  required final MessagePartTool part,
  required final ToolOutputFetch output,

  /// Fetches a summary's output; null for a full part, which has it.
  required final VoidCallback? fetchOutput,
}) extends StatefulWidget {
  @override
  State<_ToolPanel> createState() => _ToolPanelState();
}

class _ToolPanelState() extends State<_ToolPanel> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    // The panel opens during a build, which must not change the cubit.
    if (widget.output is! ToolOutputLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.fetchOutput?.call();
      });
    }
  }

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
    final command = widget.part.state.shellCommand;
    final fetch = widget.output;
    final (output, error) = switch (fetch) {
      ToolOutputLoaded(:final output, :final error) => (output, error),
      ToolOutputLoading() || ToolOutputFailed() => (null, null),
    };
    final fetchOutput = widget.fetchOutput;
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
                    command != null ? loc.sessionDetailShell : ToolPartWidget.toolName(loc: loc, part: widget.part),
                    style: style,
                  ),
                ),
                // A transcript missing its output is not offered for copying.
                // The button keeps its room, so the title does not move when
                // the output arrives.
                Visibility(
                  visible: fetch is ToolOutputLoaded,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: PregoCopyIconButton(
                    onCopy: () => copyTextToClipboard(
                      text: transcript,
                      operation: command != null ? "shell transcript" : "tool output",
                    ),
                    tooltip: loc.sessionDetailCopy,
                  ),
                ),
              ],
            ),
            // Fits a short transcript; a long one scrolls within this cap.
            if (blocks.isNotEmpty)
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
            if (fetch is! ToolOutputLoaded && fetchOutput != null)
              // A retry starts a new spinner delay.
              _PendingOutput(
                key: ValueKey(fetch is ToolOutputFailed),
                fetch: fetch,
                retry: fetchOutput,
                textStyle: style,
              ),
          ],
        ),
      ),
    );
  }
}

/// Stands in for a summary's output until it arrives. It keeps one height
/// whether the output loads or failed, so the panel resizes only once, when
/// the output comes; only text too large for that height grows it.
class const _PendingOutput({
  super.key,
  required final ToolOutputFetch fetch,
  required final VoidCallback retry,
  required final TextStyle textStyle,
}) extends StatefulWidget {
  /// How long the output loads before its spinner shows, so a quick fetch
  /// never flashes one.
  static const _spinnerDelay = Duration(milliseconds: 150);

  @override
  State<_PendingOutput> createState() => _PendingOutputState();
}

class _PendingOutputState() extends State<_PendingOutput> {
  late final Timer _spinnerDelay;
  bool _showsSpinner = false;

  @override
  void initState() {
    super.initState();
    _spinnerDelay = Timer(_PendingOutput._spinnerDelay, () => setState(() => _showsSpinner = true));
  }

  @override
  void dispose() {
    _spinnerDelay.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    // Large text may wrap the failure; it then grows instead of clipping.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: switch (widget.fetch) {
        ToolOutputFailed() => Row(
          children: [
            Expanded(
              child: Text(
                loc.sessionDetailToolOutputFailed,
                style: widget.textStyle.copyWith(color: prego.colors.textErrorPrimary),
              ),
            ),
            TextButton(
              key: const ValueKey("toolOutput.retry"),
              onPressed: widget.retry,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(loc.sessionDetailToolOutputRetry),
            ),
          ],
        ),
        ToolOutputLoading() || ToolOutputLoaded() => Semantics(
          label: loc.sessionDetailToolOutputLoading,
          liveRegion: true,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedOpacity(
              opacity: _showsSpinner ? 1 : 0,
              duration: transcriptMotionDuration,
              child: const SizedBox.square(
                key: ValueKey("toolOutput.spinner"),
                dimension: PregoIconSize.sm,
                child: PregoActivityIndicator(color: null),
              ),
            ),
          ),
        ),
      },
    );
  }
}
