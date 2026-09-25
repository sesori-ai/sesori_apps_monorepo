import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// How wide a modal's dialog frame is. The sheet frame always spans the
/// screen.
enum PregoModalWidth({required final double pixels}) {
  /// Forms and confirmations.
  regular(pixels: 440),

  /// Agent questions and permission requests.
  request(pixels: 520),

  /// The folder browser, whose body also takes the window's height.
  browser(pixels: 560),

  /// Long reading, such as a reasoning transcript.
  reading(pixels: 640),

  /// Whole code blocks, so typical lines fit without sideways scrolling.
  code(pixels: 880),
}

/// Presents [builder]'s content under [title] in the frame the
/// [PregoInteractionScope] picks: [showPregoBottomSheet] for touch, a centred
/// dialog of [width] for pointer.
///
/// When [isDismissible], both frames close from their close button and a
/// scrim tap; otherwise they have no close button and only the content pops. The dialog also closes on Esc when [isDismissible],
/// though the desktop shell's own Esc handling closes any dialog on top. A
/// dialog opened from a dialog stacks on it, and Esc closes only the top one.
/// [bodySize] sizes the sheet's body; in the dialog, a
/// [PregoBottomSheetBodySize.natural] body scrolls when the window is short,
/// and a sized one gets the window's height.
// ignore: no_slop_linter/prefer_required_named_parameters, isDismissible/bodySize/width keep the common modal's defaults
Future<T?> showPregoModal<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool isDismissible = true,
  PregoBottomSheetBodySize bodySize = PregoBottomSheetBodySize.natural,
  PregoModalWidth width = PregoModalWidth.regular,
}) {
  return switch (PregoInteractionScope.of(context)) {
    PregoInteractionMode.touch => showPregoBottomSheet<T>(
      context: context,
      title: title,
      builder: builder,
      isDismissible: isDismissible,
      bodySize: bodySize,
    ),
    PregoInteractionMode.pointer => _showDialogFrame<T>(
      context: context,
      isDismissible: isDismissible,
      builder: (dialogContext) => _PregoDialogFrame(
        title: title,
        subtitle: null,
        onBack: null,
        // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; pops the dialog this helper pushed
        onClose: isDismissible ? () => Navigator.of(dialogContext).pop() : null,
        width: width,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
        scrolls: bodySize == PregoBottomSheetBodySize.natural,
        child: builder(dialogContext),
      ),
    ),
  };
}

/// Presents a modal whose [builder] returns its own [PregoModalSurface] or
/// [PregoActionSheet], for a header that follows the content. The route is a
/// bottom sheet for touch and a dialog for pointer, as in [showPregoModal].
Future<T?> showPregoModalRoute<T>({required BuildContext context, required WidgetBuilder builder}) {
  return switch (PregoInteractionScope.of(context)) {
    // ignore: no_slop_linter/avoid_raw_modal_presenters, this is the adaptive presenter
    PregoInteractionMode.touch => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      // The surface paints its own rounded background.
      backgroundColor: Colors.transparent,
      // The surface caps itself just below the status bar.
      useSafeArea: false,
      builder: builder,
    ),
    PregoInteractionMode.pointer => _showDialogFrame<T>(context: context, isDismissible: true, builder: builder),
  };
}

/// A modal surface whose header follows its content, such as a title that
/// tracks the current question: [PregoBottomSheet] under a touch
/// [PregoInteractionScope], a centred dialog [width] wide under a pointer one.
///
/// Present it with [showPregoModalRoute]. The body is full-bleed and pads
/// itself. A body that hosts its own scroll view bounds its height, as
/// [PregoBottomSheet] requires; the dialog also caps it at the window.
/// [handleBottomSafeArea] and [topInset] apply to the sheet only.
class const PregoModalSurface({
  super.key,
  required final String title,
  required final String? subtitle,
  required final VoidCallback? onBack,
  required final VoidCallback onClose,
  required final PregoModalWidth width,
  required final bool handleBottomSafeArea,
  required final double topInset,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return switch (PregoInteractionScope.of(context)) {
      PregoInteractionMode.touch => PregoBottomSheet(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        onClose: onClose,
        contentPadding: EdgeInsetsDirectional.zero,
        handleBottomSafeArea: handleBottomSafeArea,
        topInset: topInset,
        child: child,
      ),
      PregoInteractionMode.pointer => _PregoDialogFrame(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        onClose: onClose,
        width: width,
        contentPadding: EdgeInsetsDirectional.zero,
        scrolls: false,
        child: child,
      ),
    };
  }
}

Future<T?> _showDialogFrame<T>({
  required BuildContext context,
  required bool isDismissible,
  required WidgetBuilder builder,
}) {
  // ignore: no_slop_linter/avoid_raw_modal_presenters, this is the adaptive presenter
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    animationStyle: prefersReducedMotion(context) ? AnimationStyle.noAnimation : null,
    builder: builder,
  );
}

/// The pointer frame: a centred panel with the title at the start, a back
/// button before it when the content steps back, and a close button at the
/// end. It is painted in the bottom sheet's surface colour, so tiles and fields
/// built for the sheet keep their contrast; its border and corners match the
/// desktop settings window.
class const _PregoDialogFrame({
  required final String title,
  required final String? subtitle,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
  required final PregoModalWidth width,
  required final EdgeInsetsGeometry contentPadding,

  /// Whether the body scrolls inside the frame. A body that bounds itself
  /// instead gets the frame's remaining height as its limit.
  required final bool scrolls,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final localizations = MaterialLocalizations.of(context);
    final subtitle = this.subtitle;
    final body = Padding(padding: contentPadding, child: child);
    return Dialog(
      backgroundColor: prego.colors.bgSecondary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(PregoSpacing.x4l),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PregoRadius.x4l),
        side: BorderSide(color: prego.colors.borderSecondary),
      ),
      child: SizedBox(
        width: width.pixels,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                PregoSpacing.xl,
                PregoSpacing.md,
                PregoSpacing.md,
                PregoSpacing.md,
              ),
              child: Row(
                spacing: PregoSpacing.xs,
                children: [
                  if (onBack case final onBack?)
                    IconButton(
                      tooltip: localizations.backButtonTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onBack,
                      icon: const Icon(TablerRegular.arrow_left, size: PregoIconSize.md),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (onClose case final onClose?)
                    IconButton(
                      tooltip: localizations.closeButtonTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onClose,
                      icon: const Icon(TablerRegular.x, size: PregoIconSize.md),
                    ),
                ],
              ),
            ),
            Flexible(child: scrolls ? SingleChildScrollView(child: body) : body),
          ],
        ),
      ),
    );
  }
}
