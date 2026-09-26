import "dart:async";

import "package:flutter/gestures.dart" show kPrimaryButton;
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../session_detail/widgets/voice_cancel_button.dart";
import "feedback_sheet_motion.dart";

const _pressScale = 0.97;
const _pressOpacity = 0.8;
const _pressFadeDuration = Duration(milliseconds: 100);

/// The counter appears once this few characters remain.
const _counterThreshold = 200;

/// A shorter hold is a tap, not speech, and is discarded like the session
/// composer's.
const _minimumRecordingDuration = Duration(milliseconds: 200);

/// Drag-to-cancel geometry around the cancel target's centre: the drag starts
/// engaging it within the reach radius and commits within the commit radius.
const _cancelReachRadius = 170.0;
const _cancelCommitRadius = 44.0;

enum _VoicePresentation() {
  idle,
  recording,
  transcribing,
}

/// "What should we improve?": issue pills and a message, typed or dictated by
/// holding the microphone, sent privately.
///
/// Reads the [VoiceInputCubit] the product shell provides around this step.
/// Transcripts are appended to the draft and never sent by themselves.
class const FeedbackPrivateStep({super.key, required final VoidCallback onCancel}) extends StatefulWidget {
  @override
  State<FeedbackPrivateStep> createState() => _FeedbackPrivateStepState();
}

class _FeedbackPrivateStepState() extends State<FeedbackPrivateStep> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _textScroll = ScrollController();
  final _cancelTargetKey = GlobalKey();

  /// 0 at rest, 1 with the holding finger on the cancel target.
  final _cancelProgress = ValueNotifier<double>(0);

  /// True from a press on the microphone (or an assistive-technology toggle)
  /// until its release.
  bool _holding = false;

  /// The pointer holding the microphone; null for an assistive toggle.
  int? _holdPointer;
  Timer? _minimumDurationTimer;
  bool _minimumDurationReached = false;

  VoiceInputCubit get _voice => context.read<VoiceInputCubit>();

  @override
  void initState() {
    super.initState();
    _text.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _minimumDurationTimer?.cancel();
    _text.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _text.dispose();
    _focus.dispose();
    _textScroll.dispose();
    _cancelProgress.dispose();
    super.dispose();
  }

  void _submit() {
    _focus.unfocus();
    unawaited(context.read<FeedbackSheetCubit>().submit(message: _text.text));
  }

  void _handleMicPointerDown(PointerDownEvent event) {
    if (_holding || (event.buttons & kPrimaryButton) == 0) return;
    _holdPointer = event.pointer;
    unawaited(_startRecording());
  }

  void _handleMicPointerMove(PointerMoveEvent event) {
    if (event.pointer != _holdPointer) return;
    final target = _cancelTargetKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.hasSize) return;
    final distance = (event.position - target.localToGlobal(target.size.center(Offset.zero))).distance;
    final progress = (1 - (distance - _cancelCommitRadius) / (_cancelReachRadius - _cancelCommitRadius)).clamp(
      0.0,
      1.0,
    );
    if ((progress >= 1) != (_cancelProgress.value >= 1)) unawaited(_playHaptic(play: HapticFeedback.selectionClick));
    _cancelProgress.value = progress;
  }

  void _handleMicPointerUp(PointerUpEvent event) {
    if (event.pointer == _holdPointer) unawaited(_release());
  }

  /// The system took the touch, for example when the sheet closes under the
  /// finger, so nothing was meant to be sent for transcription.
  void _handleMicPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _holdPointer) _cancelVoice();
  }

  /// Assistive technologies cannot express the hold, so activation toggles.
  void _handleSemanticToggle() {
    if (_holding) {
      unawaited(_release());
    } else {
      unawaited(_startRecording());
    }
  }

  Future<void> _startRecording() async {
    final voice = _voice;
    if (voice.state is! VoiceInputIdle) {
      _holdPointer = null;
      return;
    }
    _holding = true;
    _minimumDurationReached = false;
    _cancelProgress.value = 0;
    // Before the recorder starts, so touch-down feels immediate.
    unawaited(_playHaptic(play: HapticFeedback.lightImpact));
    await voice.startRecording();
    if (!mounted || voice.state is! VoiceInputRecording) return;
    if (!_holding) {
      // Released while the recorder was starting: nothing worth transcribing.
      await voice.cancel();
      return;
    }
    _minimumDurationTimer = Timer(_minimumRecordingDuration, () => _minimumDurationReached = true);
  }

  Future<void> _release() async {
    if (!_holding) return;
    final discard = _cancelProgress.value >= 1 || !_minimumDurationReached;
    _endHold();
    // Still starting: _startRecording cancels once the recorder is up.
    if (_voice.state is! VoiceInputRecording) return;
    if (discard) {
      await _voice.cancel();
    } else {
      await _voice.stopAndTranscribe(limitReached: false);
    }
  }

  /// Cancels the recording or transcription; the draft stays as it is.
  void _cancelVoice() {
    _endHold();
    unawaited(_voice.cancel());
  }

  void _endHold() {
    _holding = false;
    _holdPointer = null;
    _minimumDurationTimer?.cancel();
    _cancelProgress.value = 0;
  }

  void _handleVoiceState(BuildContext context, VoiceInputState state) {
    final loc = context.loc;
    switch (state) {
      case VoiceInputTranscribing(limitReached: true):
        _showNotice(message: loc.voiceRecordingLimitReached, variant: PregoPopupAlertsNotificationsVariant.warning);
      case VoiceInputCompleted(:final transcript):
        _appendTranscript(transcript: transcript);
        _voice.acknowledgeOutcome();
      case VoiceInputStartFailed(:final error):
        _endHold();
        if (error is MicrophonePermissionDeniedError) {
          _showNotice(message: loc.voiceErrorPermission, variant: PregoPopupAlertsNotificationsVariant.warning);
        } else {
          _showNotice(message: loc.voiceErrorRecording, variant: PregoPopupAlertsNotificationsVariant.error);
        }
        _voice.acknowledgeOutcome();
      case VoiceInputTranscriptionFailed(:final error):
        _showNotice(
          message: error is NotAuthenticatedVoiceError ? loc.voiceErrorNotAuthenticated : loc.voiceErrorTranscription,
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
        _voice.acknowledgeOutcome();
      case VoiceInputRetryPending():
        // The approved flow drops a recording that could not be transcribed
        // and invites a fresh one; the draft stays as it is.
        _showNotice(message: loc.voiceErrorTranscription, variant: PregoPopupAlertsNotificationsVariant.error);
        unawaited(_voice.discard());
      case VoiceInputIdle() ||
          VoiceInputStarting() ||
          VoiceInputRecording() ||
          VoiceInputTranscribing() ||
          VoiceInputRetrying() ||
          VoiceInputRetryCancelling() ||
          VoiceInputDiscarding() ||
          VoiceInputCancelling():
        break;
    }
  }

  /// Appends to whatever the draft holds now, including text typed while
  /// transcribing, and cuts the result at the server's limit.
  void _appendTranscript({required String transcript}) {
    final addition = transcript.trim();
    if (addition.isEmpty) return;
    final draft = _text.text;
    final separator = draft.isEmpty || draft.endsWith(" ") || draft.endsWith("\n") ? "" : " ";
    final text = "$draft$separator$addition".characters.take(feedbackMessageMaxLength).toString();
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    unawaited(_playHaptic(play: HapticFeedback.lightImpact));
    // Bring the new words into view once the field has laid them out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_textScroll.hasClients) return;
      final end = _textScroll.position.maxScrollExtent;
      if (prefersReducedMotion(context)) {
        _textScroll.jumpTo(end);
      } else {
        _textScroll.animateTo(end, duration: feedbackContentDuration, curve: feedbackEaseOut);
      }
    });
  }

  void _showNotice({required String message, required PregoPopupAlertsNotificationsVariant variant}) =>
      PregoPopupAlertPresenter.of(context).show(title: message, variant: variant);

  static Future<void> _playHaptic({required Future<void> Function() play}) async {
    try {
      await play();
    } on Object catch (error, stackTrace) {
      logw("Failed to play feedback voice haptics", error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VoiceInputCubit, VoiceInputState>(
      listener: _handleVoiceState,
      child: _buildContent(context: context),
    );
  }

  Widget _buildContent({required BuildContext context}) {
    final prego = context.prego;
    final loc = context.loc;
    final state = context.watch<FeedbackSheetCubit>().state;
    if (state is! FeedbackSheetPrivateFeedback) return const SizedBox.shrink();
    final editable = state.submission.canEdit;
    final failed = state.submission == FeedbackSubmission.failed;
    final sending = state.submission == FeedbackSubmission.submitting;
    final voice = switch (context.watch<VoiceInputCubit>().state) {
      VoiceInputStarting() || VoiceInputRecording() => _VoicePresentation.recording,
      VoiceInputTranscribing() || VoiceInputRetrying() => _VoicePresentation.transcribing,
      VoiceInputIdle() ||
      VoiceInputRetryPending() ||
      VoiceInputRetryCancelling() ||
      VoiceInputDiscarding() ||
      VoiceInputCompleted() ||
      VoiceInputStartFailed() ||
      VoiceInputTranscriptionFailed() ||
      VoiceInputCancelling() => _VoicePresentation.idle,
    };
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
        _buildComposer(context: context, editable: editable, sending: sending, voice: voice),
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

  Widget _buildComposer({
    required BuildContext context,
    required bool editable,
    required bool sending,
    required _VoicePresentation voice,
  }) {
    final prego = context.prego;
    final loc = context.loc;
    final focused = _focus.hasFocus;
    final canSend = editable && voice == _VoicePresentation.idle;
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
              scrollController: _textScroll,
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
            // The row keeps its 44px height in every voice state, so the draft
            // above it never moves; only the leading slot cross-fades.
            Row(
              children: [
                Expanded(
                  child: FeedbackContentTransition(
                    layoutBuilder: _leadingSlotLayout,
                    child: switch (voice) {
                      _VoicePresentation.idle => _buildCounter(context: context),
                      _VoicePresentation.recording => Row(
                        key: const ValueKey("feedback-voice-recording"),
                        children: [
                          VoiceCancelButton(key: _cancelTargetKey, progress: _cancelProgress, onCancel: _cancelVoice),
                          const SizedBox(width: PregoSpacing.md),
                          Expanded(
                            child: PregoVoiceWaveform(
                              amplitudeStream: _voice.amplitudeStream,
                              barColor: prego.colors.textPrimary,
                              dotColor: prego.colors.fgQuaternary,
                              flattenProgress: _cancelProgress,
                            ),
                          ),
                        ],
                      ),
                      _VoicePresentation.transcribing => Row(
                        key: const ValueKey("feedback-voice-transcribing"),
                        children: [
                          Tooltip(
                            message: loc.voiceCancelTranscription,
                            child: PregoButtonsSolid.iconOnly(
                              key: const ValueKey("feedback-voice-cancel-transcription"),
                              leadingIcon: TablerRegular.x,
                              hierarchy: PregoButtonsSolidHierarchy.secondary,
                              size: PregoButtonsSolidSize.lg,
                              onPressed: _cancelVoice,
                            ),
                          ),
                          const SizedBox(width: PregoSpacing.md),
                          Flexible(
                            child: PregoShimmer(
                              appearDelay: Duration.zero,
                              highlightColor: prego.colors.textPlaceholderSubtle,
                              semanticLabel: loc.voiceTranscribing,
                              child: Text(
                                loc.voiceTranscribing,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    },
                  ),
                ),
                const SizedBox(width: PregoSpacing.md),
                _buildMicrophone(context: context, editable: editable),
                const SizedBox(width: PregoSpacing.md),
                Semantics(
                  label: loc.feedbackSend,
                  button: true,
                  enabled: canSend,
                  excludeSemantics: true,
                  onTap: canSend ? _submit : null,
                  child: PregoButtonsSolid.iconOnly(
                    key: const ValueKey("feedback-send"),
                    leadingIcon: TablerRegular.arrow_up,
                    hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                    size: PregoButtonsSolidSize.lg,
                    isLoading: sending,
                    onPressed: canSend ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter({required BuildContext context}) {
    final prego = context.prego;
    final remaining = feedbackMessageMaxLength - _text.text.characters.length;
    if (remaining > _counterThreshold) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
      child: Text(
        context.loc.feedbackCharactersLeft(remaining),
        key: const ValueKey("feedback-counter"),
        style: prego.textTheme.textSm.regular.copyWith(
          color: remaining == 0 ? prego.colors.textErrorPrimary : prego.colors.textTertiary,
        ),
      ),
    );
  }

  /// Hold to record, release to transcribe, or drag onto the cancel target
  /// to discard. The button stays mounted through every voice state because
  /// it owns the hold.
  Widget _buildMicrophone({required BuildContext context, required bool editable}) {
    return Semantics(
      button: true,
      label: context.loc.voiceRecord,
      enabled: editable,
      excludeSemantics: true,
      onTap: editable ? _handleSemanticToggle : null,
      // Claims vertical drags that start on the microphone, so a hold that
      // drifts neither scrolls nor dismisses the sheet.
      child: GestureDetector(
        onVerticalDragStart: (_) {},
        child: Listener(
          onPointerDown: editable ? _handleMicPointerDown : null,
          onPointerMove: _handleMicPointerMove,
          onPointerUp: _handleMicPointerUp,
          onPointerCancel: _handleMicPointerCancel,
          child: PregoButtonsSolid.iconOnly(
            key: const ValueKey("feedback-voice"),
            leadingIcon: TablerRegular.microphone,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            // Keeps the enabled look; the listener drives recording.
            onPressed: editable ? _ignoreTap : null,
          ),
        ),
      ),
    );
  }

  static void _ignoreTap() {}
}

/// Pins every leading-slot state to the row's start edge.
Widget _leadingSlotLayout(Widget? current, List<Widget> previous) =>
    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]);

class const _IssuePill({
  super.key,
  required final String label,
  required final bool selected,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    // A light brand tint over the unselected fill, like a selected session
    // tile, so the pill reads as chosen in both themes.
    final selectedFill = Color.alphaBlend(
      prego.colors.bgBrandSolid.withValues(alpha: 0.16),
      prego.colors.bgSurface5,
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
                    border: Border.all(
                      color:
                          Color.lerp(prego.colors.borderSecondary, prego.colors.borderBrand, progress) ??
                          prego.colors.borderSecondary,
                    ),
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
                          style: prego.textTheme.textMd.medium.copyWith(
                            color: Color.lerp(prego.colors.textSecondary, prego.colors.textBrandPrimary, progress),
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
