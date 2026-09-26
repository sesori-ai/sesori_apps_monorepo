import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "feedback_sheet_motion.dart";

const _pressScale = 0.97;
const _pressOpacity = 0.8;
const _pressFadeDuration = Duration(milliseconds: 100);

/// The counter appears once this few characters remain.
const _counterThreshold = 200;

/// "What should we improve?": issue pills and a typed message, sent privately.
class const FeedbackPrivateStep({super.key, required final VoidCallback onCancel}) extends StatefulWidget {
  @override
  State<FeedbackPrivateStep> createState() => _FeedbackPrivateStepState();
}

class _FeedbackPrivateStepState() extends State<FeedbackPrivateStep> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    _focus.unfocus();
    unawaited(context.read<FeedbackSheetCubit>().submit(message: _text.text));
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = context.watch<FeedbackSheetCubit>().state;
    if (state is! FeedbackSheetPrivateFeedback) return const SizedBox.shrink();
    final editable = state.submission.canEdit;
    final failed = state.submission == FeedbackSubmission.failed;
    final sending = state.submission == FeedbackSubmission.submitting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        Text(loc.feedbackPrivateTitle, textAlign: TextAlign.center, style: prego.textTheme.textXl.medium),
        const SizedBox(height: 18),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              for (final issue in FeedbackIssue.values)
                _IssuePill(
                  key: ValueKey(issue),
                  label: switch (issue) {
                    FeedbackIssue.hardToNavigate => loc.feedbackIssueHardToNavigate,
                    FeedbackIssue.connectionDrops => loc.feedbackIssueConnectionDrops,
                    FeedbackIssue.notificationsMissing => loc.feedbackIssueNotificationsMissing,
                    FeedbackIssue.appSlow => loc.feedbackIssueAppSlow,
                  },
                  selected: state.issues.contains(issue),
                  onTap: editable ? () => context.read<FeedbackSheetCubit>().toggleIssue(issue: issue) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildComposer(context: context, editable: editable, sending: sending),
        const SizedBox(height: PregoSpacing.md),
        Text(
          loc.feedbackRecipient,
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
        ),
        FeedbackContentTransition(
          child: failed
              ? Padding(
                  key: const ValueKey("feedback-send-failed"),
                  padding: const EdgeInsetsDirectional.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        Text(
                          loc.feedbackSendFailed,
                          textAlign: TextAlign.center,
                          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textErrorPrimary),
                        ),
                        PregoButtonsSolid(
                          key: const ValueKey("feedback-retry"),
                          label: loc.feedbackRetry,
                          hierarchy: PregoButtonsSolidHierarchy.link,
                          size: PregoButtonsSolidSize.lg,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        // Figma uses secondary text on its ghost dismiss buttons.
        SizedBox(
          width: double.infinity,
          child: TextButton(
            key: const ValueKey("feedback-cancel"),
            // Closing mid-send would drop the result, so the sheet stays until it lands.
            onPressed: sending ? null : widget.onCancel,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 52),
              foregroundColor: prego.colors.textSecondary,
              disabledForegroundColor: prego.colors.textDisabled,
              textStyle: prego.textTheme.textMd.bold,
            ),
            child: Text(loc.feedbackCancel),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer({required BuildContext context, required bool editable, required bool sending}) {
    final prego = context.prego;
    final loc = context.loc;
    final focused = _focus.hasFocus;
    final remaining = feedbackMessageMaxLength - _text.text.characters.length;
    return TweenAnimationBuilder<Decoration>(
      duration: prefersReducedMotion(context) ? Duration.zero : feedbackControlDuration,
      curve: feedbackEaseOut,
      tween: DecorationTween(
        end:
            pregoComposerSurfaceDecoration(
              prego: prego,
              style: focused ? PregoComposerSurfaceStyle.emphasized : PregoComposerSurfaceStyle.subtle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(PregoRadius.x3l),
                bottom: Radius.circular(PregoRadius.x5l),
              ),
            ).copyWith(
              boxShadow: focused
                  ? [
                      BoxShadow(color: prego.colors.focusRing, spreadRadius: 4),
                      BoxShadow(color: prego.colors.bgSurface1, spreadRadius: 2),
                    ]
                  : const [],
            ),
      ),
      builder: (context, decoration, child) => DecoratedBox(decoration: decoration, child: child),
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey("feedback-text"),
              controller: _text,
              focusNode: _focus,
              readOnly: !editable,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              inputFormatters: [LengthLimitingTextInputFormatter(feedbackMessageMaxLength)],
              // Reserve the editing area before typing; longer drafts scroll.
              minLines: 3,
              maxLines: 3,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
              cursorColor: prego.colors.borderBrand,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: loc.feedbackMessageHint,
                hintStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsetsDirectional.fromSTEB(
                  PregoSpacing.xs,
                  PregoSpacing.md,
                  PregoSpacing.xs + 27,
                  PregoSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: PregoSpacing.md),
            Row(
              children: [
                Expanded(
                  child: remaining <= _counterThreshold
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                          child: Text(
                            loc.feedbackCharactersLeft(remaining),
                            key: const ValueKey("feedback-counter"),
                            style: prego.textTheme.textSm.regular.copyWith(
                              color: remaining == 0 ? prego.colors.textErrorPrimary : prego.colors.textTertiary,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Semantics(
                  label: loc.feedbackSend,
                  button: true,
                  enabled: editable,
                  excludeSemantics: true,
                  onTap: editable ? _submit : null,
                  child: PregoButtonsSolid.iconOnly(
                    key: const ValueKey("feedback-send"),
                    leadingIcon: TablerRegular.arrow_up,
                    hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                    size: PregoButtonsSolidSize.lg,
                    isLoading: sending,
                    onPressed: editable ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class const _IssuePill({
  super.key,
  required final String label,
  required final bool selected,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final selectionTint = prego.colors.bgBrandHover;
    final selectedFill = Color.alphaBlend(
      Theme.of(context).brightness == Brightness.dark
          ? selectionTint
          : selectionTint.withValues(alpha: selectionTint.a / 2),
      prego.colors.bgSurface2,
    );
    return Semantics(
      label: label,
      checked: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _FeedbackPress(
          enabled: onTap != null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: selected ? 1 : 0, end: selected ? 1 : 0),
                duration: feedbackControlDuration,
                curve: feedbackEaseOut,
                builder: (context, progress, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.lerp(prego.colors.bgSurface5, selectedFill, progress),
                    borderRadius: BorderRadius.circular(PregoRadius.full),
                    border: Border.all(color: prego.colors.borderSecondary),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color.lerp(prego.colors.bgSurface1, prego.colors.bgBrandSolid, progress),
                          borderRadius: BorderRadius.circular(PregoRadius.xs),
                          border: Border.all(
                            color:
                                Color.lerp(prego.colors.borderPrimary, prego.colors.borderBrand, progress) ??
                                prego.colors.borderPrimary,
                          ),
                        ),
                        child: Opacity(
                          opacity: progress,
                          child: Icon(TablerRegular.check, size: 13, color: prego.colors.textWhite),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pointer feedback only: semantic activation never triggers the scale.
class const _FeedbackPress({required final bool enabled, required final Widget child}) extends StatefulWidget {
  @override
  State<_FeedbackPress> createState() => _FeedbackPressState();
}

class _FeedbackPressState() extends State<_FeedbackPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pressed = widget.enabled && _pressed;
    final reducedMotion = prefersReducedMotion(context);
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: pressed && !reducedMotion ? _pressScale : 1,
        duration: reducedMotion
            ? Duration.zero
            : pressed
            ? feedbackControlDuration
            : feedbackControlReverseDuration,
        curve: feedbackEaseOut,
        child: AnimatedOpacity(
          opacity: pressed ? _pressOpacity : 1,
          duration: _pressFadeDuration,
          child: widget.child,
        ),
      ),
    );
  }
}
