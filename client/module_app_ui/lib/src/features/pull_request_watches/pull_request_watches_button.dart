import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

const Duration _motionDuration = Duration(milliseconds: 250);

/// The home bar's pull-request button. It shows while the computer has
/// watched pull requests, fading and growing in its own slot, which stays
/// empty while it is hidden so the buttons beside it never move, and carries a red count while some need the
/// user; the count rolls when it changes.
class const PullRequestWatchesButton({
  super.key,
  required final PregoButtonsIconGlassSize size,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (visible, needsYou) = switch (context.watch<PullRequestWatchListCubit>().state) {
      PullRequestWatchListLoaded(:final watches, :final needsYouCount) => (watches.isNotEmpty, needsYouCount),
      PullRequestWatchListLoading() || PullRequestWatchListFailed() || PullRequestWatchListUnsupported() => (false, 0),
    };
    final duration = context.isReducedMotion ? Duration.zero : _motionDuration;
    final loc = context.loc;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(animation), child: child),
      ),
      // Hidden, it keeps its slot empty, so the buttons beside it never move.
      child: visible
          ? Stack(
              key: const ValueKey("shown"),
              clipBehavior: Clip.none,
              children: [
                PregoButtonsIconGlass(
                  key: const Key("home-pull-requests"),
                  icon: TablerRegular.git_pull_request,
                  size: size,
                  semanticLabel: needsYou > 0
                      ? loc.pullRequestWatchesButtonNeedsYou(needsYou)
                      : loc.pullRequestWatchesTitle,
                  onPressed: onPressed,
                ),
                PositionedDirectional(
                  top: -4,
                  end: -4,
                  child: IgnorePointer(
                    child: PullRequestWatchesCountBadge(key: const Key("home-pull-requests-badge"), count: needsYou),
                  ),
                ),
              ],
            )
          : SizedBox.square(key: const ValueKey("hidden"), dimension: size.diameter),
    );
  }
}

/// The red needs-you count; it grows in from nothing and rolls between counts.
class const PullRequestWatchesCountBadge({super.key, required final int count}) extends StatefulWidget {
  @override
  State<PullRequestWatchesCountBadge> createState() => _PullRequestWatchesCountBadgeState();
}

class _PullRequestWatchesCountBadgeState() extends State<PullRequestWatchesCountBadge> {
  static const double _height = 18;

  /// The last count above zero, which a leaving badge keeps while it shrinks.
  late int _shown = widget.count;

  @override
  void didUpdateWidget(PullRequestWatchesCountBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > 0) _shown = widget.count;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final duration = context.isReducedMotion ? Duration.zero : _motionDuration;
    return ExcludeSemantics(
      child: AnimatedScale(
        scale: widget.count > 0 ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutBack,
        child: Container(
          height: _height,
          constraints: const BoxConstraints(minWidth: _height),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bgErrorSolid, borderRadius: BorderRadius.circular(_height / 2)),
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  // The new count rolls up from below; the old one leaves the top.
                  begin: Offset(0, child.key == ValueKey(_shown) ? 1 : -1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: Text(
                "$_shown",
                key: ValueKey(_shown),
                style: context.prego.textTheme.textXs.bold.copyWith(color: colors.fgWhite, height: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
