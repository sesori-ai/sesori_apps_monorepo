import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
import "../../../core/widgets/markdown_styles.dart";
import "command_formatter.dart";
import "follow_detach_scrollable.dart";
import "scroll_follow_tracker.dart";

/// Bottom sheet for a command and its live result content.
class CommandModal extends StatefulWidget {
  final String messageId;
  final CommandMessageInfo command;
  final double topInset;

  const CommandModal({
    super.key,
    required this.messageId,
    required this.command,
    required this.topInset,
  });

  static Future<void> show(
    BuildContext context, {
    required String messageId,
    required CommandMessageInfo command,
  }) {
    final cubit = context.read<SessionDetailCubit>();
    final topInset = MediaQuery.paddingOf(context).top;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CommandModal(
          messageId: messageId,
          command: command,
          topInset: topInset,
        ),
      ),
    );
  }

  @override
  State<CommandModal> createState() => _CommandModalState();
}

class _CommandModalState extends State<CommandModal> {
  static const _kListViewKey = Key("command-modal-list-view");

  late final ScrollFollowTracker _follow;

  @override
  void initState() {
    super.initState();
    _follow = ScrollFollowTracker(edge: ScrollFollowEdge.max);
  }

  @override
  void dispose() {
    _follow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultText = context.select<SessionDetailCubit, String?>(
      (cubit) => cubit.state.resolveCommandResultText(
        command: widget.command,
        messageId: widget.messageId,
      ),
    );
    final prego = context.prego;
    final loc = context.loc;
    final screenHeight = MediaQuery.heightOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final maxBody = screenHeight - widget.topInset - PregoBottomSheet.contentTopInset - keyboard;

    return PregoBottomSheet(
      title: loc.sessionDetailCommand,
      topInset: widget.topInset,
      onClose: () => context.pop(),
      contentPadding: EdgeInsetsDirectional.zero,
      handleBottomSafeArea: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(maxBody, screenHeight * 0.3)),
        child: FollowDetachScrollable(
          tracker: _follow,
          detachedOverlayBuilder: null,
          child: ListView(
            key: _kListViewKey,
            controller: _follow.scrollController,
            shrinkWrap: true,
            padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16 + bottomSafe),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: prego.colors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: prego.colors.borderSecondary),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.terminal,
                      size: 18,
                      color: prego.colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectionArea(
                        child: Text(
                          CommandFormatter.format(widget.command),
                          style: prego.textTheme.textSm.bold.monospace.copyWith(
                            color: prego.colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _originLabel(context: context, origin: widget.command.origin),
                      style: prego.textTheme.textXs.medium.copyWith(
                        color: prego.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.sessionDetailCommandResult,
                      style: prego.textTheme.textSm.bold.copyWith(
                        color: prego.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (resultText case final text? when text.trim().isNotEmpty)
                SelectionArea(
                  child: MarkdownBody(
                    data: text,
                    selectable: false,
                    onTapLink: handleMarkdownLinkTap,
                    styleSheet: buildSessionMarkdownStyleSheet(
                      prego: prego,
                      paragraphStyle: prego.textTheme.textXs.regular.copyWith(
                        color: prego.colors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  loc.sessionDetailCommandResultEmpty,
                  style: prego.textTheme.textXs.regular.copyWith(
                    color: prego.colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _originLabel({required BuildContext context, required CommandOrigin origin}) => switch (origin) {
  CommandOrigin.manual => context.loc.sessionDetailCommandOriginManual,
  CommandOrigin.automatic => context.loc.sessionDetailCommandOriginAutomatic,
  CommandOrigin.unknown => context.loc.sessionDetailCommandOriginUnknown,
};
