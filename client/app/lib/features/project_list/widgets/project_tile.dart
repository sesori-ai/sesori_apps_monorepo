import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:path/path.dart" as p;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/constants.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../l10n/app_localizations.dart";
import "../rename_project_dialog.dart";

/// The user-facing directory of [project]: its live path on disk, falling
/// back to the id for payloads from older bridges that don't send a path
/// (there the id is the directory).
// COMPATIBILITY 2026-07-10 (v1.5.0): Old bridges may omit Project.path. Remove this fallback when the shared path default is removed.
String projectDisplayPath(Project project) => project.path.isEmpty ? project.id : project.path;

/// The last segment of [project]'s directory, used as the display-name
/// fallback when the project has no stored name. The directory comes from the
/// bridge's host platform, not the phone's, so both separator styles must
/// parse — the platform-local basename would return a Windows path unchanged.
String projectDirectoryBasename(Project project) =>
    p.posix.basename(_toPosix(projectDisplayPath(project)));

/// [project]'s directory, shortened to the part that tells projects apart.
///
/// A row is far too narrow for a real path, and clipping one with an ellipsis
/// would eat the tail — the only segments that differ between projects — and
/// leave every row reading `/Users/someone/workspace/clien…`. So the head is
/// dropped instead of the tail: the last two segments survive, marked with a
/// leading ellipsis when anything was actually removed.
String projectShortPath(Project project) {
  final segments = _toPosix(projectDisplayPath(project)).split("/").where((s) => s.isNotEmpty).toList();
  if (segments.length <= _shortPathSegments) return segments.join("/");
  return "…/${segments.sublist(segments.length - _shortPathSegments).join("/")}";
}

const int _shortPathSegments = 2;

/// Bridges run on the phone's host or a Windows machine, so both separator
/// styles reach us; the path libraries only parse one of them.
String _toPosix(String path) => path.replaceAll(r"\", "/");

/// A single project row in the connected project list.
///
/// Tapping opens the project's sessions. Long-pressing — or right-clicking with
/// a mouse — opens the row's actions — rename, hide — in a [PregoAnchorMenu]
/// anchored to the row, so the project being acted on stays visible beside the
/// menu instead of being covered by a bottom sheet.
///
/// The same actions are also behind a swipe ([PregoSwipeActions]): a partial
/// swipe toward the start edge settles the row open on a rename button and a
/// hide pill, and a full swipe commits the hide directly. The swipe is the
/// quick path; the menu stays the discoverable and assistive one.
///
/// The menu is forced flat on every platform ([PregoAnchorMenu.flat]), like the
/// onboarding support menu: the glass popup morphs out of its trigger's bounds,
/// which for a full-width row reads as the row collapsing into a small panel,
/// and it allocates a ticker, a scroll controller and an unaspected MediaQuery
/// dependency for every realised row of the list.
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.activeSessions,
    required this.unseen,
  });

  final Project project;

  /// How many of the project's sessions an agent is working in right now.
  final int activeSessions;

  /// Whether the project has activity the user hasn't opened yet.
  final bool unseen;

  /// Wide enough for the longest action label without the panel spanning the
  /// row it is anchored to.
  static const double _menuWidth = 200;

  @override
  Widget build(BuildContext context) {
    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      // While the menu is open the rest of the list blurs back and this row
      // stays sharp, so which project the actions will hit is unambiguous.
      spotlight: PregoMenuSpotlight.listRow,
      entriesBuilder: () => _actionEntries(context: context),
      triggerBuilder: (context, openMenu) => _buildRow(context: context, openMenu: openMenu),
    );
  }

  /// The long-press actions for this project. [PregoAnchorMenu] dismisses the
  /// menu before running an entry's `onTap`, so both of these act against the
  /// still-mounted tile rather than a popped route.
  List<PregoMenuEntry> _actionEntries({required BuildContext context}) {
    final loc = context.loc;
    return [
      PregoMenuItem(
        leadingIcon: TablerRegular.pencil,
        title: loc.rename,
        subtitle: null,
        isSelected: false,
        onTap: () => _rename(context: context),
      ),
      PregoMenuItem(
        leadingIcon: TablerRegular.eye_off,
        title: loc.hideProject,
        subtitle: null,
        isSelected: false,
        onTap: () => unawaited(_hide(context: context)),
      ),
    ];
  }

  void _rename({required BuildContext context}) {
    showRenameProjectDialog(
      context: context,
      project: project,
      cubit: context.read<ProjectListCubit>(),
    );
  }

  /// A confirmed hide drops the project from the list, which disposes this
  /// tile — so the messenger and strings are resolved before the cubit call,
  /// not after it.
  Future<void> _hide({required BuildContext context}) async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    final hidden = await context.read<ProjectListCubit>().hideProject(project.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(hidden ? loc.projectHidden : loc.projectHideFailed),
        duration: kSnackBarDuration,
      ),
    );
  }

  Widget _buildRow({required BuildContext context, required VoidCallback openMenu}) {
    final loc = context.loc;
    final prego = context.prego;
    final displayName = project.name ?? _fallbackName(loc: loc);
    // The project's folder was moved or deleted on disk. Surface it as
    // unavailable and block navigation so we don't drive into a dead path;
    // Hide/Rename stay available via long-press.
    final missing = project.directoryMissing;
    // An unavailable project's whole row recedes; the status line stays a shade
    // darker than the rest so the reason is still legible.
    final dimmed = missing ? prego.colors.textDisabled : null;

    return PregoSwipeActions(
      showBottomHairline: true,
      actionsBuilder: (context, close) => [
        _renameAction(context: context, close: close),
      ],
      primaryActionBuilder: (context, close) => _hideAction(context: context, close: close),
      onFullSwipe: () => unawaited(_hide(context: context)),
      // Right-click is the mouse counterpart of long-press. The row also has
      // to announce itself as a button and as one thing: that came free from
      // ListTile, whereas an InkWell contributes only the actions, not the
      // role, and leaves the row's three lines as three separate nodes to
      // swipe past.
      child: GestureDetector(
        onSecondaryTap: openMenu,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => _open(context: context, displayName: displayName, missing: missing),
              onLongPress: openMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PregoSpacing.xl,
                  vertical: PregoSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: PregoSpacing.xs,
                        children: [
                          _titleRow(prego: prego, displayName: displayName, dimmed: dimmed),
                          Text(
                            projectShortPath(project),
                            style: prego.textTheme.textSm.regular.copyWith(
                              color: dimmed ?? prego.colors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          _StatusRow(project: project, activeSessions: activeSessions, unseen: unseen),
                        ],
                      ),
                    ),
                    ExcludeSemantics(
                      child: Icon(
                        TablerLight.chevron_right,
                        size: _chevronSize,
                        color: dimmed ?? prego.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The swipe strip's rename button. Icon-only, so the label rides in the
  /// semantics instead.
  Widget _renameAction({required BuildContext context, required VoidCallback close}) => _actionPill(
    label: null,
    icon: TablerRegular.pencil,
    hierarchy: PregoButtonsSolidHierarchy.secondary,
    semanticsLabel: context.loc.rename,
    close: close,
    onPressed: () => _rename(context: context),
  );

  /// The swipe strip's hide pill — the primary action, which is also what a
  /// full swipe commits. Sized by its own content at rest; when
  /// [PregoSwipeActions] widens its box during an overdrag, the button's
  /// centered content rides the stretch. Not `fullWidth`: that needs a
  /// bounded parent, and at rest the strip's width is open-ended.
  Widget _hideAction({required BuildContext context, required VoidCallback close}) => _actionPill(
    label: context.loc.hide,
    icon: TablerRegular.eye_off,
    hierarchy: PregoButtonsSolidHierarchy.primary,
    type: PregoButtonsSolidType.warning,
    semanticsLabel: null,
    close: close,
    onPressed: () => unawaited(_hide(context: context)),
  );

  /// Builds one of the swipe strip's pills: medium size and the close-then-
  /// dispatch sequencing are shared by both, and a null [label] switches to
  /// the icon-only variant with [semanticsLabel] carrying the spoken name in
  /// its place — the only other differences between the two are hierarchy
  /// and tone.
  Widget _actionPill({
    required String? label,
    required IconData icon,
    required PregoButtonsSolidHierarchy hierarchy,
    PregoButtonsSolidType type = PregoButtonsSolidType.regular,
    required String? semanticsLabel,
    required VoidCallback close,
    required VoidCallback onPressed,
  }) {
    void onTap() {
      close();
      onPressed();
    }

    final button = label == null
        ? PregoButtonsSolid.iconOnly(
            leadingIcon: icon,
            hierarchy: hierarchy,
            size: PregoButtonsSolidSize.md,
            onPressed: onTap,
          )
        : PregoButtonsSolid(
            label: label,
            leadingIcon: icon,
            hierarchy: hierarchy,
            type: type,
            size: PregoButtonsSolidSize.md,
            onPressed: onTap,
          );
    return semanticsLabel == null ? button : Semantics(label: semanticsLabel, child: button);
  }

  Widget _titleRow({
    required PregoDesignSystem prego,
    required String displayName,
    required Color? dimmed,
  }) {
    return Row(
      spacing: PregoSpacing.sm,
      children: [
        ExcludeSemantics(
          child: Icon(
            TablerSolid.folder,
            size: _folderSize,
            color: dimmed ?? prego.colors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            displayName,
            // Unopened activity leans on weight rather than a badge.
            style: (unseen ? prego.textTheme.textMd.medium : prego.textTheme.textMd.regular).copyWith(
              color: dimmed ?? prego.colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _fallbackName({required AppLocalizations loc}) {
    final lastSegment = projectDirectoryBasename(project);
    return lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName;
  }

  void _open({required BuildContext context, required String displayName, required bool missing}) {
    if (missing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.loc.projectFolderMissingMessage),
          duration: kSnackBarDuration,
        ),
      );
      return;
    }
    context.read<ProjectListCubit>().setActiveProject(project);
    context.pushRoute(
      AppRoute.sessions(
        projectId: project.id,
        projectName: displayName,
        supportsDedicatedWorktrees: project.supportsDedicatedWorktrees,
      ),
    );
  }
}

/// The row's third line: what the project is doing, then when it last changed.
///
/// The status is a single slot with one occupant. A project can be both running
/// and unseen; a live turn is the more informative of the two, so it wins, and
/// the unseen state still shows through the title's weight.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.project,
    required this.activeSessions,
    required this.unseen,
  });

  final Project project;
  final int activeSessions;
  final bool unseen;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final missing = project.directoryMissing;
    // COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges may omit Project.time, leaving a project with no timestamp to show. Remove the null branch when the shared field becomes non-null.
    final updatedAt = project.time?.updated;

    // The line box is held open even when there is nothing to say, so a project
    // with no status and no timestamp doesn't shrink its row out of the list's
    // pitch. A minimum rather than a fixed height: scaled-up accessibility text
    // grows the row instead of being cropped to the 1x line box.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _statusLineHeight),
      child: Row(
        spacing: PregoSpacing.md,
        children: [
          // The label yields and ellipsizes when the line runs out of width —
          // a narrow screen under a large text size — so it can't push the
          // timestamp out of the row.
          if (missing)
            Flexible(
              child: _StatusLabel(
                icon: const Icon(TablerRegular.circle_x, size: _statusIconSize),
                label: loc.projectFolderMissing,
              ),
            )
          else if (activeSessions > 0)
            Flexible(
              child: _StatusLabel(
                icon: PregoAiLoader(phase: PregoAiLoader.phaseFor(project.id)),
                label: loc.projectListRunning(activeSessions),
              ),
            )
          else if (unseen)
            Flexible(
              child: _StatusLabel(
                // Unopened activity is a state, not an event: the sparkle marks
                // it without moving, and the label carries the emphasis instead.
                icon: const PregoAiLoader(animate: false),
                label: loc.projectListNewActivity,
                emphasis: true,
              ),
            ),
          // An unavailable project's timestamp is noise — the folder is gone.
          if (!missing && updatedAt != null)
            Text(
              context.formatTimestamp(updatedAt),
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
            ),
        ],
      ),
    );
  }

}

/// An icon and its label, as one status.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.label,
    this.emphasis = false,
  });

  final Widget icon;
  final String label;

  /// Whether the label is the row's headline rather than a quiet aside.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Row(
      // Hugs its content: inside the status row's Flexible slot a max-sized Row
      // would claim the whole allotment and strand the timestamp at the far end.
      mainAxisSize: MainAxisSize.min,
      spacing: PregoSpacing.xs,
      children: [
        IconTheme.merge(
          data: IconThemeData(color: prego.colors.textTertiary),
          child: SizedBox(width: _statusSlotWidth, child: Center(child: icon)),
        ),
        Flexible(
          child: Text(
            label,
            style: prego.textTheme.textSm.regular.copyWith(
              color: emphasis ? prego.colors.textPrimary : prego.colors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The project row's loading state: the same geometry, with the text replaced
/// by bars, so the list keeps its pitch and nothing jumps when the data lands.
///
/// Decorative on its own — wrap a column of these in a single [PregoShimmer],
/// never one per row.
class ProjectTileSkeleton extends StatelessWidget {
  const ProjectTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PregoSpacing.xl,
        vertical: PregoSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: prego.colors.borderTertiary, width: 0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PregoSpacing.xs,
              children: [
                // The chrome the row would show anyway is drawn, not faked: only
                // the parts that are actually still loading become bars.
                Row(
                  spacing: PregoSpacing.sm,
                  children: [
                    Icon(TablerSolid.folder, size: _folderSize, color: prego.colors.textDisabled),
                    // Align loosens the line box's tight height, so the bar is
                    // centred in it rather than stretched to fill it.
                    const SizedBox(
                      height: _titleLineHeight,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: PregoSkeletonBar(height: 20, width: 175),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _pathLineHeight, child: PregoSkeletonBar(height: 20, width: 141)),
                const SizedBox(height: _statusLineHeight, child: PregoSkeletonBar(height: 20, width: 94)),
              ],
            ),
          ),
          Icon(TablerLight.chevron_right, size: _chevronSize, color: prego.colors.textSecondary),
        ],
      ),
    );
  }
}

/// The row's line boxes, from the type scale it renders: a 16/24 title over two
/// 14/20 detail lines. Named so the skeleton can hold the same shape without
/// re-deriving it from text it doesn't draw.
const double _titleLineHeight = 24;
const double _pathLineHeight = 20;
const double _statusLineHeight = 20;

const double _folderSize = 16;
const double _chevronSize = 16;
const double _statusIconSize = 16;

/// The status icon sits in a fixed slot so the labels of the different statuses
/// line up with each other down the list.
const double _statusSlotWidth = 20;
