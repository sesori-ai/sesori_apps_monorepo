import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../feedback/feedback_sheet_motion.dart";

const _package = "sesori_app_ui";

/// Invites the user to book a call with the CEO, in [copy]'s wording or the
/// built-in one. Resolves true when the user chose to book, once the sheet
/// has fully closed, so the booking page never cuts its exit short.
Future<bool> showFounderCallSheet({required BuildContext context, required FounderCallCopy copy}) async {
  final reducedMotion = prefersReducedMotion(context);
  ModalRoute<bool>? sheetRoute;
  // ignore: no_slop_linter/avoid_raw_modal_presenters, mobile-only grabber sheet with the feedback sheet's drawer motion, which showPregoModalRoute cannot carry
  final book = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    sheetAnimationStyle: AnimationStyle(
      duration: reducedMotion ? Duration.zero : feedbackSheetOpenDuration,
      reverseDuration: reducedMotion ? Duration.zero : feedbackSheetCloseDuration,
      curve: feedbackDrawerCurve,
      reverseCurve: feedbackEaseOut.flipped,
    ),
    builder: (context) {
      sheetRoute = ModalRoute.of<bool>(context);
      return _FounderCallSheet(copy: copy);
    },
  );
  // A popped sheet's result completes before its closing animation does.
  await sheetRoute?.completed;
  return book ?? false;
}

/// The feedback sheet's grabber chrome and buttons around the CEO's photo,
/// so both prompts that open by themselves look like one family.
class const _FounderCallSheet({required final FounderCallCopy copy}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route showFounderCallSheet pushed
    void close({required bool book}) => Navigator.of(context).pop(book);
    return Material(
      color: prego.colors.bgSurface2,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(PregoRadius.x8l)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: prego.colors.textPrimary,
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                    ),
                  ),
                ),
              ),
              Stack(
                children: [
                  const _FounderCallHero(),
                  Positioned(
                    right: -2,
                    top: -1,
                    child: IconButton(
                      key: const Key("founder_call_close"),
                      constraints: const BoxConstraints.tightFor(width: 52, height: 52),
                      // The feedback sheet's dark disc keeps the ✕ legible on
                      // the sky in both themes.
                      icon: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                        child: SizedBox.square(
                          dimension: 30,
                          child: Icon(
                            TablerRegular.x,
                            size: 18,
                            color: prego.colors.fgWhite,
                            semanticLabel: loc.founderCallClose,
                          ),
                        ),
                      ),
                      onPressed: () => close(book: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                copy.title ?? loc.founderCallTitle,
                textAlign: TextAlign.center,
                style: prego.textTheme.textXl.medium,
              ),
              const SizedBox(height: PregoSpacing.xs),
              Text(
                loc.founderCallName,
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textTertiary),
              ),
              const SizedBox(height: PregoSpacing.md),
              Text(
                copy.message ?? loc.founderCallMessage,
                textAlign: TextAlign.center,
                style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
              ),
              const SizedBox(height: PregoSpacing.x3l),
              PregoButtonsSolid(
                key: const Key("founder_call_book"),
                label: copy.buttonLabel ?? loc.founderCallBook,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                onPressed: () => close(book: true),
              ),
              const SizedBox(height: 12),
              PregoButtonsSolid(
                key: const Key("founder_call_not_now"),
                label: loc.founderCallNotNow,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                onPressed: () => close(book: false),
              ),
              // viewPadding, as in the feedback sheet, so the gap stays put.
              SizedBox(height: 12 + math.max(32, MediaQuery.viewPaddingOf(context).bottom + 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The feedback sheet's sky with the CEO's photo in a ringed circle.
class const _FounderCallHero() extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: AspectRatio(
        aspectRatio: 370 / 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset("assets/images/feedback_rating_background.webp", package: _package, fit: BoxFit.cover),
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.prego.colors.fgWhite, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                  image: const DecorationImage(
                    image: AssetImage("assets/images/founder_call_photo.webp", package: _package),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
