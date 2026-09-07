// UI-only feedback prototype approved for local design review. All service
// outcomes are simulated; this entry point never initializes the product app.
import "dart:async";
import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_mobile/core/widgets/sesori_logo.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() => runApp(const FeedbackFlowPlaybook(openOnLaunch: true));

enum FeedbackPreviewScenario({required final String label}) {
  success(label: "Successful feedback"),
  submissionRetry(label: "Submission fails once"),
  microphoneDenied(label: "Microphone permission denied"),
  transcriptionRetry(label: "Transcription fails once"),
  nativeUnavailable(label: "Native review unavailable"),
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

class _PreviewLauncherState() extends State<_PreviewLauncher> {
  FeedbackPreviewScenario _scenario = FeedbackPreviewScenario.success;
  String? _notice;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    if (widget.openOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openFeedback());
      });
    }
  }

  Future<void> _openFeedback() async {
    if (_presenting) return;
    setState(() {
      _presenting = true;
      _notice = null;
    });
    final scenario = _scenario;
    final result = await showModalBottomSheet<_PreviewOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => _FeedbackSheet(scenario: scenario),
    );
    if (!mounted) return;
    switch (result) {
      case _PreviewOutcome.privateFeedback:
        setState(() => _notice = "Feedback sent. Thank you!");
      case _PreviewOutcome.nativeReview:
        // The launcher survives sheet disposal. This is a Figma mock, never
        // StoreKit, Play Review, a store link, or a network request.
        if (scenario == FeedbackPreviewScenario.nativeUnavailable) {
          setState(() => _notice = "Native review unavailable · preview");
        } else {
          await showDialog<void>(context: context, builder: (_) => const _NativeReviewPreview());
        }
      case null:
        break;
    }
    if (mounted) setState(() => _presenting = false);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Scaffold(
      body: Stack(
        children: [
          PregoGlassScaffold(
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
                      "UI only. Voice, submission, and store review are simulated. Nothing is recorded or sent.",
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
                      "Try 1–3 stars for private feedback, or 4–5 stars for the store-review preview. "
                      "Dismiss to change the scenario or theme.",
                      style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
          if (_notice case final notice?)
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: PregoPopupAlertsNotifications(
                    title: notice,
                    variant: notice == "Feedback sent. Thank you!"
                        ? PregoPopupAlertsNotificationsVariant.success
                        : PregoPopupAlertsNotificationsVariant.info,
                    onClose: () => setState(() => _notice = null),
                  ),
                ),
              ),
            ),
        ],
      ),
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

/// Grabber-only Figma sheet: the production PregoBottomSheet has a navigation
/// header. Keep this preview chrome local instead of changing that component.
class const _FeedbackSheet({required final FeedbackPreviewScenario scenario}) extends StatefulWidget {
  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState() extends State<_FeedbackSheet> {
  int? _rating;
  bool _choosingRating = false;

  Future<void> _chooseRating({required int rating}) async {
    if (_choosingRating) return;
    setState(() {
      _rating = rating;
      _choosingRating = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
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
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedPadding(
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
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
                child: AnimatedSize(
                  duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: ratingStep
                      ? _RatingStep(selected: _rating, onChoose: _chooseRating)
                      : _PrivateFeedbackStep(scenario: widget.scenario),
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
        _Stars(selected: selected, onChoose: onChoose, nativePreview: false),
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
  required final bool nativePreview,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var rating = 1; rating <= 5; rating++) ...[
        if (rating > 1) const SizedBox(width: 8),
        Semantics(
          label: "${nativePreview ? 'Preview ' : ''}$rating ${rating == 1 ? 'star' : 'stars'}",
          button: true,
          selected: selected == rating,
          excludeSemantics: true,
          onTap: () => onChoose(rating: rating),
          child: SizedBox.square(
            dimension: 44,
            child: IconButton(
              key: ValueKey("${nativePreview ? 'native' : 'rating'}-$rating"),
              padding: EdgeInsets.zero,
              onPressed: () => onChoose(rating: rating),
              icon: Icon(
                selected != null && rating <= selected! ? TablerSolid.star : TablerRegular.star,
                size: nativePreview ? 26 : 40,
                color: nativePreview
                    ? context.prego.colors.textBrandSecondary
                    : selected != null && rating <= selected!
                    ? context.prego.colors.textPrimary
                    : context.prego.colors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class const _PrivateFeedbackStep({required final FeedbackPreviewScenario scenario}) extends StatefulWidget {
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
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(6),
      decoration:
          pregoComposerSurfaceDecoration(
            prego: prego,
            style: PregoComposerSurfaceStyle.subtle,
            borderRadius: BorderRadius.circular(expanded ? PregoRadius.x3l : PregoRadius.full),
          ).copyWith(
            border: Border.all(
              color: _focus.hasFocus ? prego.colors.focusRing : prego.colors.borderSecondary,
              width: _focus.hasFocus ? 2 : 1,
            ),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expanded)
            TextField(
              key: const ValueKey("feedback-text"),
              controller: _text,
              focusNode: _focus,
              readOnly: !keyboardMode || busy,
              onTap: busy ? null : _typeFeedback,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: hasText ? 3 : 1,
              maxLines: 6,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
              cursorColor: prego.colors.borderBrand,
              decoration: InputDecoration(
                hintText: "Example: Hard to navigate",
                hintStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(6),
              ),
            ),
          if (expanded) const SizedBox(height: 8),
          Row(
            children: [
              if (!keyboardMode)
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _voice == _VoiceStage.recording ? "Finish recording" : "Hold to talk to give feedback",
                    excludeSemantics: true,
                    onTap: busy ? null : () => _voice == _VoiceStage.recording ? _transcribe() : _startRecording(),
                    child: GestureDetector(
                      key: const ValueKey("feedback-voice"),
                      behavior: HitTestBehavior.opaque,
                      onTap: busy ? null : () => _voice == _VoiceStage.recording ? _transcribe() : _startRecording(),
                      onLongPressStart: busy ? null : (_) => _startRecording(),
                      onLongPressEnd: busy ? null : (_) => _transcribe(),
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: switch (_voice) {
                            _VoiceStage.recording => const _RecordingPreview(),
                            _VoiceStage.transcribing => Text("Transcribing…", style: prego.textTheme.textSm.regular),
                            _ => Text(
                              hasText ? "Hold to talk more" : "Hold to talk to give feedback",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (_voice != _VoiceStage.recording && _voice != _VoiceStage.transcribing)
                _ComposerButton(
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
              if (hasText || _issues.isNotEmpty || keyboardMode) ...[
                const SizedBox(width: 6),
                _ComposerButton(
                  label: "Send feedback",
                  icon: TablerRegular.arrow_up,
                  primary: true,
                  loading: busy,
                  onPressed: _canSend ? _submit : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class const _IssuePill({required final String label, required final bool selected, required final VoidCallback? onTap})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Semantics(
      label: label,
      checked: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: prego.colors.bgSurface5,
                borderRadius: BorderRadius.circular(PregoRadius.full),
                border: Border.all(color: selected ? prego.colors.borderBrand : prego.colors.borderSecondary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: selected ? prego.colors.bgBrandSolid : prego.colors.bgSurface1,
                      borderRadius: BorderRadius.circular(PregoRadius.xs),
                      border: Border.all(color: selected ? prego.colors.borderBrand : prego.colors.borderPrimary),
                    ),
                    child: selected ? Icon(TablerRegular.check, size: 13, color: prego.colors.textWhite) : null,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: prego.textTheme.textMd.medium.copyWith(
                        color: selected ? prego.colors.textPrimary : prego.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
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

class const _NativeReviewPreview() extends StatefulWidget {
  @override
  State<_NativeReviewPreview> createState() => _NativeReviewPreviewState();
}

class _NativeReviewPreviewState() extends State<_NativeReviewPreview> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Dialog(
      backgroundColor: prego.colors.bgSurface3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.x5l)),
      insetPadding: const EdgeInsets.all(28),
      child: SizedBox(
        width: 304,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 64, child: SesoriLogo(squareSize: 54)),
              const SizedBox(height: 8),
              Text("Enjoying Sesori?", style: prego.textTheme.textLg.bold),
              Text("Tap a star to rate it on the App Store.", style: prego.textTheme.textMd.medium),
              const SizedBox(height: 12),
              Divider(color: prego.colors.borderPrimary, height: 1),
              const SizedBox(height: 8),
              Center(
                child: _Stars(
                  selected: _rating,
                  onChoose: ({required rating}) => setState(() => _rating = rating),
                  nativePreview: true,
                ),
              ),
              const SizedBox(height: 8),
              PregoButtonsSolid(
                label: _rating == null ? "Not Now" : "Done",
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Preview · no store request",
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
