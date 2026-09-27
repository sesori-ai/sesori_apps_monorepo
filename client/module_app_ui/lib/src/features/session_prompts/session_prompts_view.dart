import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "widgets/prompt_day_header.dart";
import "widgets/prompt_spine_row.dart";

const double _kHeaderHeight = 52;

/// The Prompts screen: the session's loaded prompts in the transcript's order,
/// earlier above, grouped under their days. It opens on [anchorMessageId]'s
/// row, tinted, just below its day's heading.
class const SessionPromptsView({
  super.key,
  required final TranscriptPromptList prompts,

  /// The prompt the reader was on when the screen opened; null or not listed
  /// opens at the newest end with nothing tinted.
  required final String? anchorMessageId,

  /// Caps the list's width, centred; null spans the pane.
  required final double? maxWidth,
  required final void Function({required String messageId}) onPromptTap,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<SessionPromptsView> createState() => _SessionPromptsViewState();
}

/// A run of prompts sharing one day, or every prompt when none has a time.
typedef _Group = ({DateTime? day, List<TranscriptPromptEntry> entries});

class _SessionPromptsViewState() extends State<SessionPromptsView> {
  ScrollController? _scrollController;

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  static List<_Group> _groupsOf({required TranscriptPromptList list}) {
    if (!list.hasTimes) return [(day: null, entries: list.entries)];
    final groups = <_Group>[];
    for (final entry in list.entries) {
      if (groups.lastOrNull case final group? when group.day == entry.dayKey) {
        group.entries.add(entry);
      } else {
        groups.add((day: entry.dayKey, entries: [entry]));
      }
    }
    return groups;
  }

  /// The offset that rests the anchored row just below its day's pinned
  /// heading, from the fixed extents above it; the newest end without one.
  double _initialOffset({
    required List<_Group> groups,
    required bool grouped,
    required String? highlightedId,
    required double rowExtent,
    required double headerExtent,
    required double trailingExtent,
    required double viewport,
  }) {
    var above = 0.0;
    double? anchored;
    for (final group in groups) {
      if (grouped) above += headerExtent;
      for (final entry in group.entries) {
        if (entry.messageId == highlightedId) anchored = above - (grouped ? headerExtent : 0);
        above += rowExtent;
      }
    }
    final maxOffset = math.max(0.0, above + trailingExtent - viewport);
    return (anchored ?? maxOffset).clamp(0.0, maxOffset);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final padding = MediaQuery.paddingOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final list = widget.prompts;
    final groups = _groupsOf(list: list);
    final grouped = list.hasTimes;
    final highlightedId = list.entries.any((entry) => entry.messageId == widget.anchorMessageId)
        ? widget.anchorMessageId
        : null;
    final rowExtent = promptRowExtent(textScaler: textScaler);
    final headerExtent = promptDayHeaderExtent(textScaler: textScaler);
    final countStyle = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);
    final countExtent = textScaler.scale(12) * 18 / 12 + PregoSpacing.xl * 2;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            height: padding.top + _kHeaderHeight,
            padding: EdgeInsetsDirectional.only(top: padding.top, start: PregoSpacing.xl, end: PregoSpacing.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: prego.colors.borderSecondary, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(loc.transcriptPrompts, style: prego.textTheme.textMd.medium),
                  ),
                ),
                IconButton(
                  key: const Key("session-prompts-close"),
                  tooltip: loc.transcriptPromptsClose,
                  icon: const Icon(TablerRegular.x, size: PregoIconSize.md),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: list.entries.isEmpty
                ? Center(child: Text(loc.transcriptPromptsEmpty, style: countStyle))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final scrollController = _scrollController ??= ScrollController(
                        initialScrollOffset: _initialOffset(
                          groups: groups,
                          grouped: grouped,
                          highlightedId: highlightedId,
                          rowExtent: rowExtent,
                          headerExtent: headerExtent,
                          trailingExtent: countExtent + padding.bottom,
                          viewport: constraints.maxHeight,
                        ),
                      );
                      final maxWidth = widget.maxWidth;
                      final inset = maxWidth == null ? 0.0 : math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
                      SliverFixedExtentList rows({required List<TranscriptPromptEntry> entries}) =>
                          SliverFixedExtentList.builder(
                            itemExtent: rowExtent,
                            itemCount: entries.length,
                            itemBuilder: (context, index) => PromptSpineRow(
                              key: ValueKey(entries[index].messageId),
                              entry: entries[index],
                              showsTime: grouped,
                              highlighted: entries[index].messageId == highlightedId,
                              onTap: () => widget.onPromptTap(messageId: entries[index].messageId),
                            ),
                          );
                      return CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          for (final group in groups)
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: inset),
                              sliver: grouped
                                  ? SliverMainAxisGroup(
                                      slivers: [
                                        SliverPersistentHeader(
                                          pinned: true,
                                          delegate: PromptDayHeaderDelegate(
                                            label: switch (group.day) {
                                              final day? => context.formatDayLabel(day: day),
                                              null => loc.transcriptPromptsNoDate,
                                            },
                                            extent: headerExtent,
                                          ),
                                        ),
                                        rows(entries: group.entries),
                                      ],
                                    )
                                  : rows(entries: group.entries),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: countExtent + padding.bottom,
                              child: Padding(
                                padding: EdgeInsetsDirectional.only(bottom: padding.bottom),
                                child: Center(
                                  child: Text(loc.transcriptPromptsLoaded(list.promptCount), style: countStyle),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
