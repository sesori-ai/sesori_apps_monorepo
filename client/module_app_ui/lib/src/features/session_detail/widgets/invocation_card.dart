import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../widgets/markdown_styles.dart";
import "sent_bubble_landing.dart";
import "user_message_card.dart";

/// A command, skill or MCP prompt the user ran, as an event in the transcript
/// rather than a chat bubble: what ran over the arguments typed with it. It is
/// a record, not a control, so it takes no taps.
class const InvocationCard({
  super.key,
  required final String name,
  required final CommandSource source,
  required final String? arguments,
  required final List<Widget> attachments,

  /// Whether the card waits, outlined, for the harness to take it.
  required final bool outlined,
  required final Duration transitionDuration,
}) extends StatelessWidget {
  static const double _padding = PregoSpacing.lg;

  static IconData _icon({required CommandSource source}) => switch (source) {
    CommandSource.command => TablerRegular.terminal,
    CommandSource.skill => TablerRegular.sparkles,
    CommandSource.mcp => TablerRegular.plug_connected,
    CommandSource.unknown => TablerRegular.slash,
  };

  static String _label({required CommandSource source, required AppLocalizations loc}) => switch (source) {
    CommandSource.command => loc.commandSourceCommand,
    CommandSource.skill => loc.commandSourceSkill,
    CommandSource.mcp => loc.commandSourceMcp,
    CommandSource.unknown => loc.commandSourceCustom,
  };

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final arguments = this.arguments;
    const margin = UserMessageBubble.margin;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          container: true,
          label: loc.invocationCardSemantics(source.name, name),
          // A command whose arguments were dictated lands its words here, as a bubble does.
          child: SentBubbleSlot(
            text: arguments,
            child: AnimatedContainer(
              duration: transitionDuration,
              curve: Curves.easeInOutCubic,
              margin: margin,
              padding: const EdgeInsets.all(_padding),
              constraints: BoxConstraints(
                maxWidth:
                    UserMessageBubble.maxContentWidth(rowWidth: constraints.maxWidth) + UserMessageBubble.padding * 2,
              ),
              decoration: BoxDecoration(
                color: prego.colors.bgSecondary,
                border: Border.all(color: prego.colors.borderSecondary),
                borderRadius: BorderRadius.circular(PregoRadius.x2l),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PregoRadius.x2l),
                border: Border.all(
                  color: prego.colors.borderBrand.withValues(alpha: outlined ? 0.55 : 0),
                ),
              ),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PregoTag(
                          icon: _icon(source: source),
                          label: _label(source: source, loc: loc),
                        ),
                        const SizedBox(height: PregoSpacing.md),
                        Text(
                          loc.invocationCardRan(name),
                          // The arguments' own size, so the two read as one message at every scale.
                          style: (buildChatMessageMarkdownStyleSheet(prego: prego).p ?? prego.textTheme.textMd.regular)
                              .copyWith(fontWeight: FontWeight.w500, color: prego.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (attachments.isNotEmpty || arguments != null) ...[
                    const SizedBox(height: PregoSpacing.sm),
                    UserMessageBubbleContent(
                      markdown: arguments,
                      attachments: attachments,
                      alignment: .start,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
