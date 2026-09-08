// Local feedback prototype. Voice and submission are simulated; 4–5 stars
// requests Apple's native rating UI through an iOS debug-only channel.
import "dart:async";
import "dart:math" as math;

import "package:flutter/services.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() => runApp(const FeedbackFlowPlaybook(openOnLaunch: true));

enum FeedbackPreviewScenario({required final String label}) {
  success(label: "Successful feedback"),
  submissionRetry(label: "Submission fails once"),
  microphoneDenied(label: "Microphone permission denied"),
  transcriptionRetry(label: "Transcription fails once"),
}

enum _PreviewOutcome() {
  privateFeedback,
  nativeReview,
}

enum _InputMode() {
  voice,
  keyboard,
}

enum _VoiceStage() {
  idle,
  recording,
  transcribing,
  denied,
  failed,
}

enum _SubmissionStage() {
  editing,
  submitting,
  failed,
}

const _sampleTranscript =
    "The design is clean, but I kept getting lost in the navigation. "
    "It would help to make it easier to find my recent tasks.";

const _ratingBounceDuration = Duration(milliseconds: 280);
// Occasional feedback transitions connect states; typing keeps a stable editor.
const _feedbackEaseOut = Cubic(0.23, 1, 0.32, 1);
const _feedbackDrawerCurve = Cubic(0.32, 0.72, 0, 1);
const _feedbackTransitionDuration = Duration(milliseconds: 220);
const _feedbackControlDuration = Duration(milliseconds: 160);

/// Run with `flutter run -t test/playbook/feedback_flow_playbook.dart`.
/// The launcher labels the simulation; the sheets preserve the product copy.
class const FeedbackFlowPlaybook({super.key, required final bool openOnLaunch}) extends StatefulWidget {
  @override
  State<FeedbackFlowPlaybook> createState() => _FeedbackFlowPlaybookState();
}

class _FeedbackFlowPlaybookState() extends State<FeedbackFlowPlaybook> {
  ThemeMode _theme = ThemeMode.dark;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "Sesori feedback preview",
    debugShowCheckedModeBanner: false,
    theme: buildPregoThemeData(brightness: Brightness.light),
    darkTheme: buildPregoThemeData(brightness: Brightness.dark),
    themeMode: _theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: _PreviewLauncher(
      openOnLaunch: widget.openOnLaunch,
      onToggleTheme: () => setState(() => _theme = _theme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
    ),
  );
}

class const _PreviewLauncher({
  required final bool openOnLaunch,
  required final VoidCallback onToggleTheme,
}) extends StatefulWidget {
  @override
  State<_PreviewLauncher> createState() => _PreviewLauncherState();
}

class _PreviewLauncherState()
    extends State<_PreviewLauncher>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  FeedbackPreviewScenario _scenario = FeedbackPreviewScenario.success;
  bool _presenting = false;
  late final AnimationController _sheetAnimation = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.openOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openFeedback());
      });
    }
  }

  @override
  void didChangeAccessibilityFeatures() => setState(_syncSheetMotion);

  void _syncSheetMotion() {
    final reducedMotion = prefersReducedMotion(context);
    _sheetAnimation.duration = reducedMotion ? Duration.zero : const Duration(milliseconds: 250);
    _sheetAnimation.reverseDuration = reducedMotion ? Duration.zero : const Duration(milliseconds: 200);
    if (reducedMotion && _sheetAnimation.isAnimating) {
      _sheetAnimation.value = _sheetAnimation.status == AnimationStatus.reverse ? 0 : 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetAnimation.dispose();
    super.dispose();
  }

  Future<void> _openFeedback() async {
    if (_presenting) return;
    _syncSheetMotion();
    final popupAlertPresenter = PregoPopupAlertPresenter.of(context);
    popupAlertPresenter.dismiss();
    setState(() => _presenting = true);
    final scenario = _scenario;
    ModalRoute<_PreviewOutcome>? sheetRoute;
    final result = await showModalBottomSheet<_PreviewOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionAnimationController: _sheetAnimation,
      sheetAnimationStyle: AnimationStyle(curve: _feedbackDrawerCurve, reverseCurve: _feedbackEaseOut.flipped),
      builder: (context) {
        sheetRoute = ModalRoute.of<_PreviewOutcome>(context);
        return _FeedbackSheet(scenario: scenario);
      },
    );
    // A popped sheet's result completes before its closing animation does.
    await sheetRoute?.completed;
    if (!mounted) return;
    switch (result) {
      case _PreviewOutcome.privateFeedback:
        popupAlertPresenter.show(
          title: "Feedback sent. Thank you!",
          variant: PregoPopupAlertsNotificationsVariant.success,
        );
      case _PreviewOutcome.nativeReview:
        try {
          await const MethodChannel("com.sesori.app/feedback_preview").invokeMethod<void>("requestReview");
        } on MissingPluginException {
          if (mounted) popupAlertPresenter.show(title: "Native rating is available in the iOS debug preview.");
        } on PlatformException {
          if (mounted) popupAlertPresenter.show(title: "Couldn’t open native rating. Please try again.");
        }
      case null:
        break;
    }
    if (mounted) setState(() => _presenting = false);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return PregoGlassScaffold(
      title: "Sesori_app_monorepo",
      titleMode: PregoTopNavigationTitleMode.backLeading,
      automaticallyImplyLeading: false,
      subtitle: MediaQuery.textScalerOf(context).scale(14) > 18
          ? null
          : const PregoNavSubtitle(text: "sesori-ai/sesori_app_monorepo", icon: TablerRegular.brand_github),
      actions: [
        PregoButtonsIconGlass(
          icon: Theme.of(context).brightness == Brightness.dark ? TablerRegular.sun : TablerRegular.moon,
          semanticLabel: "Toggle preview theme",
          onPressed: widget.onToggleTheme,
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          sliver: SliverList.list(
            children: [
              const _BackdropLine(icon: TablerRegular.terminal_2, label: "OpenCode"),
              const SizedBox(height: 20),
              const _BackdropLine(icon: TablerRegular.git_branch, label: "main"),
              const SizedBox(height: 20),
              Text("Dedicated workspace", style: prego.textTheme.textMd.regular),
              const SizedBox(height: 52),
              Text("Feedback preview", style: prego.textTheme.textXl.medium),
              const SizedBox(height: 8),
              Text(
                "Voice and feedback submission are simulated. 4–5 stars opens Apple’s native rating prompt in iOS debug builds.",
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<FeedbackPreviewScenario>(
                initialValue: _scenario,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Preview scenario"),
                items: [
                  for (final scenario in FeedbackPreviewScenario.values)
                    DropdownMenuItem(value: scenario, child: Text(scenario.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _scenario = value);
                },
              ),
              const SizedBox(height: 24),
              PregoButtonsSolid(
                label: "Open feedback",
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                onPressed: _presenting ? null : _openFeedback,
              ),
              const SizedBox(height: 14),
              Text(
                "Try 1–3 stars for private feedback, or 4–5 stars for Apple’s native rating prompt. "
                "Dismiss to change the scenario or theme.",
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class const _BackdropLine({required final IconData icon, required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: context.prego.colors.textSecondary),
      const SizedBox(width: 8),
      Text(label, style: context.prego.textTheme.textMd.regular),
      const SizedBox(width: 6),
      Icon(TablerRegular.selector, size: 16, color: context.prego.colors.textTertiary),
    ],
  );
}

/// Retire outgoing controls without leaving duplicate hit targets or semantics.
class const _FeedbackContentTransition({
  required final Widget child,
  final AnimatedSwitcherLayoutBuilder layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reducedMotion = prefersReducedMotion(context);
    return AnimatedSwitcher(
      duration: _feedbackTransitionDuration,
      reverseDuration: _feedbackControlDuration,
      switchInCurve: _feedbackEaseOut,
      switchOutCurve: _feedbackEaseOut.flipped,
      layoutBuilder: (current, previous) => layoutBuilder(
        current,
        [for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child))],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: reducedMotion ? Offset.zero : const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// Size the incoming step immediately so its fade and the shell resize share
// one transition. Outgoing artwork keeps its intrinsic size while fading out.
Widget _feedbackStepLayout({required Widget? current, required List<Widget> previous}) => Stack(
  alignment: Alignment.topCenter,
  clipBehavior: Clip.none,
  children: [
    for (final child in previous)
      Positioned.fill(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ?current,
  ],
);

/// This bounded width reveal keeps the voice label and adjacent action together.
class const _FeedbackActionTransition({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reducedMotion = prefersReducedMotion(context);
    return AnimatedSwitcher(
      duration: _feedbackControlDuration,
      reverseDuration: const Duration(milliseconds: 100),
      switchInCurve: _feedbackEaseOut,
      switchOutCurve: _feedbackEaseOut.flipped,
      layoutBuilder: (current, previous) => AnimatedSwitcher.defaultLayoutBuilder(
        current,
        [for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child))],
      ),
      transitionBuilder: (child, animation) {
        final content = FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: reducedMotion ? 1 : 0.95, end: 1).animate(animation),
            child: child,
          ),
        );
        return reducedMotion ? content : SizeTransition(axis: Axis.horizontal, sizeFactor: animation, child: content);
      },
      child: child,
    );
  }
}

/// Pointer feedback only: semantic activation and typing never trigger scale.
class const _FeedbackPress({required final bool enabled, required final Widget child}) extends StatefulWidget {
  @override
  State<_FeedbackPress> createState() => _FeedbackPressState();
}

class _FeedbackPressState() extends State<_FeedbackPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pressed = widget.enabled && _pressed;
    return Listener(
      onPointerDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: pressed && !prefersReducedMotion(context) ? 0.97 : 1,
        duration: prefersReducedMotion(context)
            ? Duration.zero
            : pressed
            ? _feedbackControlDuration
            : const Duration(milliseconds: 100),
        curve: _feedbackEaseOut,
        child: AnimatedOpacity(
          opacity: pressed ? 0.8 : 1,
          duration: const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Grabber-only Figma sheet: the production PregoBottomSheet has a navigation
/// header. Keep this preview chrome local instead of changing that component.
class const _FeedbackSheet({required final FeedbackPreviewScenario scenario}) extends StatefulWidget {
  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState() extends State<_FeedbackSheet> with WidgetsBindingObserver {
  int? _rating;
  bool _choosingRating = false;
  final _privateFeedbackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _chooseRating({required int rating}) async {
    if (_choosingRating) return;
    setState(() {
      _rating = rating;
      _choosingRating = true;
    });
    await Future<void>.delayed(
      prefersReducedMotion(context) ? const Duration(milliseconds: 100) : _ratingBounceDuration,
    );
    if (!mounted) return;
    if (rating >= 4) {
      Navigator.of(context).pop(_PreviewOutcome.nativeReview);
    } else {
      setState(() => _choosingRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final ratingStep = _rating == null || _choosingRating;
    final reducedMotion = prefersReducedMotion(context);
    final step = ratingStep
        ? _RatingStep(selected: _rating, onChoose: _chooseRating)
        : _PrivateFeedbackStep(key: _privateFeedbackKey, scenario: widget.scenario);
    final content = _FeedbackContentTransition(
      layoutBuilder: (current, previous) => _feedbackStepLayout(current: current, previous: previous),
      child: KeyedSubtree(key: ValueKey(ratingStep), child: step),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Material(
        color: context.prego.colors.bgSurface2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PregoRadius.x8l)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      color: context.prego.colors.textPrimary,
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: reducedMotion
                    ? content
                    : AnimatedSize(
                        duration: _feedbackTransitionDuration,
                        curve: _feedbackEaseOut,
                        alignment: Alignment.topCenter,
                        child: content,
                      ),
              ),
              SizedBox(height: keyboard > 0 ? 12 : math.max(32, MediaQuery.paddingOf(context).bottom + 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class const _RatingStep({
  required final int? selected,
  required final void Function({required int rating}) onChoose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Image.asset("assets/images/feedback_preview_hero.png", width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 18),
        Text("How’s Sesori working for you?", textAlign: TextAlign.center, style: prego.textTheme.textXl.medium),
        const SizedBox(height: 4),
        Text(
          "Your rating helps us make it better.",
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: 36),
        _Stars(selected: selected, onChoose: onChoose),
        const SizedBox(height: 22),
        _DismissButton(
          label: "Not now",
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class const _Stars({
  required final int? selected,
  required final void Function({required int rating}) onChoose,
}) extends StatelessWidget {
  // A rating is accepted once before advancing: dip, pop, then softly settle.
  static final _tapScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.88).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 16,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.88, end: 1.18).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 34,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 0.98).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.98, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 18,
    ),
  ]);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var rating = 1; rating <= 5; rating++) ...[
        if (rating > 1) const SizedBox(width: 8),
        Semantics(
          label: "$rating ${rating == 1 ? 'star' : 'stars'}",
          button: true,
          selected: selected == rating,
          excludeSemantics: true,
          onTap: () => onChoose(rating: rating),
          child: SizedBox.square(
            dimension: 44,
            child: IconButton(
              key: ValueKey("rating-$rating"),
              padding: EdgeInsets.zero,
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed) ? Colors.transparent : null,
                ),
              ),
              onPressed: () => onChoose(rating: rating),
              icon: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: selected == rating ? 1 : 0),
                duration: prefersReducedMotion(context) ? Duration.zero : _ratingBounceDuration,
                builder: (context, progress, child) => Transform.scale(
                  scale: prefersReducedMotion(context) ? 1 : _tapScale.transform(progress),
                  child: child,
                ),
                child: SvgPicture.asset(
                  selected != null && rating <= selected!
                      ? "assets/images/feedback_star_selected.svg"
                      : "assets/images/feedback_star_default.svg",
                  width: 44,
                  height: 44,
                  excludeFromSemantics: true,
                  colorMapper: _StarColorMapper(
                    fill: selected != null && rating <= selected!
                        ? context.prego.colors.fgWarningSecondary
                        : context.prego.colors.bgSurface1,
                    stroke: selected != null && rating <= selected!
                        ? Colors.black
                        : context.prego.colors.borderSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

// Preserve the exported Figma paths while resolving their semantic theme colors.
class const _StarColorMapper({required final Color fill, required final Color stroke}) extends ColorMapper {
  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) => switch (attributeName) {
    "fill" => fill,
    "stroke" => stroke,
    _ => color,
  };

  @override
  bool operator ==(Object other) => other is _StarColorMapper && fill == other.fill && stroke == other.stroke;

  @override
  int get hashCode => Object.hash(fill, stroke);
}

class const _PrivateFeedbackStep({super.key, required final FeedbackPreviewScenario scenario}) extends StatefulWidget {
  @override
  State<_PrivateFeedbackStep> createState() => _PrivateFeedbackStepState();
}

class _PrivateFeedbackStepState() extends State<_PrivateFeedbackStep> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _issues = <String>{};
  _InputMode _mode = _InputMode.voice;
  _VoiceStage _voice = _VoiceStage.idle;
  _SubmissionStage _submission = _SubmissionStage.editing;
  bool _submissionFailedOnce = false;
  bool _transcriptionFailedOnce = false;

  bool get _canSend =>
      (_issues.isNotEmpty || _text.text.trim().isNotEmpty) &&
      _submission != _SubmissionStage.submitting &&
      _voice != _VoiceStage.recording &&
      _voice != _VoiceStage.transcribing;

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

  void _typeFeedback() {
    setState(() {
      _mode = _InputMode.keyboard;
      _voice = _VoiceStage.idle;
    });
    _focus.requestFocus();
  }

  void _startRecording() {
    if (_submission == _SubmissionStage.submitting || _voice == _VoiceStage.transcribing) return;
    _focus.unfocus();
    setState(() {
      _mode = _InputMode.voice;
      _voice = widget.scenario == FeedbackPreviewScenario.microphoneDenied ? _VoiceStage.denied : _VoiceStage.recording;
    });
  }

  Future<void> _transcribe() async {
    if (_voice != _VoiceStage.recording && _voice != _VoiceStage.failed) return;
    setState(() => _voice = _VoiceStage.transcribing);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted || _voice != _VoiceStage.transcribing) return;
    if (widget.scenario == FeedbackPreviewScenario.transcriptionRetry && !_transcriptionFailedOnce) {
      setState(() {
        _transcriptionFailedOnce = true;
        _voice = _VoiceStage.failed;
      });
      return;
    }
    setState(() => _voice = _VoiceStage.idle);
    _text.text = _text.text.trim().isEmpty ? _sampleTranscript : "${_text.text.trim()} $_sampleTranscript";
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    _focus.unfocus();
    setState(() => _submission = _SubmissionStage.submitting);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    if (widget.scenario == FeedbackPreviewScenario.submissionRetry && !_submissionFailedOnce) {
      setState(() {
        _submissionFailedOnce = true;
        _submission = _SubmissionStage.failed;
      });
      return;
    }
    Navigator.of(context).pop(_PreviewOutcome.privateFeedback);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final busy = _submission == _SubmissionStage.submitting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 18),
        Text("What should we improve?", textAlign: TextAlign.center, style: prego.textTheme.textXl.medium),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              for (final issue in const [
                "Hard to navigate",
                "Connection drops",
                "Notifications don’t arirve",
                "App feels slow",
              ])
                _IssuePill(
                  label: issue,
                  selected: _issues.contains(issue),
                  onTap: busy
                      ? null
                      : () => setState(() {
                          if (!_issues.add(issue)) _issues.remove(issue);
                        }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildComposer(context: context),
        _FeedbackContentTransition(
          child: Column(
            key: ValueKey((
              _voice == _VoiceStage.denied,
              _voice == _VoiceStage.failed,
              _submission == _SubmissionStage.failed,
            )),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_voice == _VoiceStage.denied) ...[
                const SizedBox(height: 12),
                _InlineMessage(
                  message: "Microphone access is off. You can type your feedback instead.",
                  action: "Use keyboard",
                  onAction: _typeFeedback,
                ),
              ],
              if (_voice == _VoiceStage.failed) ...[
                const SizedBox(height: 12),
                _InlineMessage(
                  message: "Couldn’t transcribe that. Try again or use the keyboard.",
                  action: "Retry transcription",
                  onAction: _transcribe,
                ),
              ],
              if (_submission == _SubmissionStage.failed) ...[
                const SizedBox(height: 12),
                _InlineMessage(
                  message: "Couldn’t send feedback. Your draft is still here.",
                  action: "Retry",
                  onAction: _submit,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DismissButton(
          label: "Cancel",
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildComposer({required BuildContext context}) {
    final prego = context.prego;
    final hasText = _text.text.isNotEmpty;
    final keyboardMode = _mode == _InputMode.keyboard;
    final busy = _submission == _SubmissionStage.submitting;
    final expanded = hasText || keyboardMode;
    final controls = _buildComposerControls(context: context);
    final radius = BorderRadius.vertical(
      top: const Radius.circular(PregoRadius.x3l),
      bottom: Radius.circular(keyboardMode ? PregoRadius.x5l : PregoRadius.x6l),
    );

    // Figma 5035:11030: the voice pill sits 6px inside the expanded editor.
    // DecoratedBox keeps the border out of that measured content inset.
    return TweenAnimationBuilder<Decoration>(
      key: const ValueKey("feedback-composer"),
      duration: prefersReducedMotion(context) ? Duration.zero : _feedbackControlDuration,
      curve: _feedbackEaseOut,
      tween: DecorationTween(
        end: expanded
            ? pregoComposerSurfaceDecoration(
                prego: prego,
                style: _focus.hasFocus ? PregoComposerSurfaceStyle.emphasized : PregoComposerSurfaceStyle.subtle,
                borderRadius: radius,
              ).copyWith(
                boxShadow: _focus.hasFocus
                    ? [
                        BoxShadow(color: prego.colors.focusRing, spreadRadius: 4),
                        BoxShadow(color: prego.colors.bgSurface1, spreadRadius: 2),
                      ]
                    : const [],
              )
            : const BoxDecoration(),
      ),
      builder: (context, decoration, child) => DecoratedBox(decoration: decoration, child: child),
      child: Padding(
        padding: EdgeInsets.all(expanded ? PregoSpacing.sm : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FeedbackContentTransition(
              child: expanded
                  ? TextField(
                      key: const ValueKey("feedback-text"),
                      controller: _text,
                      focusNode: _focus,
                      readOnly: !keyboardMode || busy,
                      onTap: busy ? null : _typeFeedback,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      // Reserve the editing area before typing; longer drafts scroll.
                      minLines: 3,
                      maxLines: 3,
                      style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
                      cursorColor: prego.colors.borderBrand,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: "Example: Hard to navigate",
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
                    )
                  : const SizedBox.shrink(),
            ),
            if (expanded) const SizedBox(height: PregoSpacing.md),
            if (keyboardMode)
              controls
            else
              DecoratedBox(
                key: const ValueKey("feedback-voice-pill"),
                decoration: pregoComposerSurfaceDecoration(
                  prego: prego,
                  style: PregoComposerSurfaceStyle.subtle,
                  borderRadius: BorderRadius.circular(PregoRadius.full),
                ).copyWith(boxShadow: const []),
                child: Padding(padding: const EdgeInsets.all(PregoSpacing.sm), child: controls),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerControls({required BuildContext context}) {
    final prego = context.prego;
    final hasText = _text.text.isNotEmpty;
    final keyboardMode = _mode == _InputMode.keyboard;
    final busy = _submission == _SubmissionStage.submitting;
    final voiceBusy = _voice == _VoiceStage.recording || _voice == _VoiceStage.transcribing;
    final transcriptReady = hasText && !keyboardMode;
    return Row(
      children: [
        if (!keyboardMode)
          Expanded(
            child: Semantics(
              button: true,
              label: _voice == _VoiceStage.recording
                  ? "Finish recording"
                  : hasText
                  ? "Hold to talk more"
                  : "Hold to talk to give feedback",
              excludeSemantics: true,
              onTap: busy ? null : () => _voice == _VoiceStage.recording ? _transcribe() : _startRecording(),
              child: GestureDetector(
                key: const ValueKey("feedback-voice"),
                behavior: HitTestBehavior.opaque,
                onTap: busy ? null : () => _voice == _VoiceStage.recording ? _transcribe() : _startRecording(),
                onLongPressStart: busy ? null : (_) => _startRecording(),
                onLongPressEnd: busy ? null : (_) => _transcribe(),
                child: _FeedbackPress(
                  enabled: !busy && _voice != _VoiceStage.transcribing,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: _FeedbackContentTransition(
                        child: KeyedSubtree(
                          key: ValueKey((_voice, hasText)),
                          child: switch (_voice) {
                            _VoiceStage.recording => const _RecordingPreview(),
                            _VoiceStage.transcribing => Text("Transcribing…", style: prego.textTheme.textSm.regular),
                            _ => Padding(
                              // Balance the trailing 44px Send action, as in Figma.
                              padding: EdgeInsetsDirectional.only(start: transcriptReady ? 44 : 0),
                              child: Text(
                                hasText ? "Hold to talk more" : "Hold to talk to give feedback",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                              ),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          const Spacer(),
        _FeedbackActionTransition(
          child: transcriptReady
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.md),
                  child: _ComposerButton(
                    label: "Send feedback",
                    icon: TablerRegular.arrow_up,
                    primary: true,
                    loading: busy,
                    onPressed: _canSend ? _submit : null,
                  ),
                )
              : !voiceBusy
              ? Padding(
                  padding: EdgeInsetsDirectional.only(start: keyboardMode ? 0 : PregoSpacing.md),
                  child: _ComposerButton(
                    label: keyboardMode ? "Use voice input" : "Use keyboard",
                    icon: keyboardMode ? TablerRegular.microphone : TablerRegular.keyboard,
                    primary: false,
                    loading: false,
                    onPressed: busy
                        ? null
                        : keyboardMode
                        ? () {
                            _focus.unfocus();
                            setState(() => _mode = _InputMode.voice);
                          }
                        : _typeFeedback,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        _FeedbackActionTransition(
          child: !transcriptReady && (_issues.isNotEmpty || keyboardMode)
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.sm),
                  child: _ComposerButton(
                    label: "Send feedback",
                    icon: TablerRegular.arrow_up,
                    primary: true,
                    loading: busy,
                    onPressed: _canSend ? _submit : null,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class const _IssuePill({required final String label, required final bool selected, required final VoidCallback? onTap})
    extends StatelessWidget {
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
                duration: _feedbackControlDuration,
                curve: _feedbackEaseOut,
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
                            color: Color.lerp(prego.colors.borderPrimary, prego.colors.borderBrand, progress)!,
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
                          style: prego.textTheme.textMd.medium.copyWith(
                            color: prego.colors.textSecondary,
                          ),
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

class const _ComposerButton({
  required final String label,
  required final IconData icon,
  required final bool primary,
  required final bool loading,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    enabled: onPressed != null,
    excludeSemantics: true,
    onTap: onPressed,
    child: PregoButtonsSolid.iconOnly(
      leadingIcon: icon,
      hierarchy: primary ? PregoButtonsSolidHierarchy.primaryAlt : PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.lg,
      isLoading: loading,
      onPressed: onPressed,
    ),
  );
}

/// Figma uses secondary text on its ghost dismiss buttons.
class const _DismissButton({required final String label, required final VoidCallback onPressed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 52),
        foregroundColor: context.prego.colors.textSecondary,
        textStyle: context.prego.textTheme.textMd.bold,
      ),
      child: Text(label),
    ),
  );
}

class const _InlineMessage({
  required final String message,
  required final String action,
  required final VoidCallback onAction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textErrorPrimary),
        ),
        PregoButtonsSolid(
          label: action,
          hierarchy: PregoButtonsSolidHierarchy.link,
          size: PregoButtonsSolidSize.lg,
          onPressed: onAction,
        ),
      ],
    ),
  );
}

class const _RecordingPreview() extends StatefulWidget {
  @override
  State<_RecordingPreview> createState() => _RecordingPreviewState();
}

class _RecordingPreviewState() extends State<_RecordingPreview> {
  late final Stream<double> _samples = Stream<double>.periodic(
    const Duration(milliseconds: 100),
    (index) => 0.2 + math.sin(index * 1.7).abs() * 0.65,
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: PregoVoiceWaveform(
      amplitudeStream: _samples,
      barColor: context.prego.colors.textPrimary,
      dotColor: context.prego.colors.textQuaternary,
    ),
  );
}
