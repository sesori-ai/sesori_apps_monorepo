import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// Empty state for the sessions list when a project has no active sessions
/// yet: a terminal-window glyph, an invitation to begin, and a chip naming the
/// project the first task will run in.
///
/// Rendered inside a `SliverFillRemaining(hasScrollBody: false)`, so the glyph
/// is a fixed size — an unbounded illustration would inflate the scroll extent.
class SessionEmptyState extends StatelessWidget {
  final String? projectName;

  const SessionEmptyState({super.key, required this.projectName});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final name = projectName;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: _EmptyTerminalGlyph(key: Key("session-empty-terminal")),
          ),
          const SizedBox(height: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.loc.sessionListEmptyTitle,
                textAlign: TextAlign.center,
                style: prego.textTheme.textLg.regular.copyWith(color: prego.colors.textPrimary),
              ),
              if (name != null) ...[
                SizedBox(height: prego.spacing.lg),
                _ProjectChip(name: name),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A small mac-style terminal window: three window-control dots, a green shell
/// prompt, and a blinking-style cursor bar — drawn in pure Flutter so it scales
/// crisply and themes with the design system (no bundled asset).
class _EmptyTerminalGlyph extends StatelessWidget {
  const _EmptyTerminalGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Container(
      width: 154,
      height: 113,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: prego.colors.bgSurface4,
        borderRadius: BorderRadius.circular(prego.radius.lg),
        border: Border.all(width: 0.5, color: prego.colors.borderInsideReversedBottom),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(7, 6, 7, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed macOS window-control colours — brand-neutral window chrome,
            // not theme tokens.
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WindowDot(Color(0xFFFF5F57)),
                SizedBox(width: 4),
                _WindowDot(Color(0xFFFEBC2E)),
                SizedBox(width: 4),
                _WindowDot(Color(0xFF28C840)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r"$",
                  // The glyph is a fixed-size illustration whose other elements
                  // (dots, cursor bar) don't scale, so the prompt must not
                  // partially scale with accessibility fonts either.
                  textScaler: TextScaler.noScaling,
                  style: prego.textTheme.textMd.regular.copyWith(
                    color: prego.colors.textSuccessPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                _CursorBar(color: prego.colors.bgBrandSolid),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  final Color color;

  const _WindowDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The shell cursor: a static brand-blue bar with a soft glow.
class _CursorBar extends StatelessWidget {
  final Color color;

  const _CursorBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 9)],
      ),
    );
  }
}

/// Non-interactive pill naming the project the first task will run in.
class _ProjectChip extends StatelessWidget {
  final String name;

  const _ProjectChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: prego.spacing.lg, vertical: prego.spacing.md),
        decoration: BoxDecoration(
          color: prego.colors.bgSurface2,
          borderRadius: BorderRadius.circular(prego.radius.full),
          border: Border.all(color: prego.colors.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerSolid.brand_github, size: 14, color: prego.colors.textPrimary),
            SizedBox(width: prego.spacing.sm),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
