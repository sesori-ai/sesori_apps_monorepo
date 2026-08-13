import "dart:math" as math;

import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";
import "pending_request_auto_dismiss.dart";

/// Bottom sheet that presents all server-driven questions within a single
/// [SesoriQuestionAsked] event, one at a time.
///
/// Each question keeps an editable local draft. The user can move freely
/// between questions, and the request is submitted only after every question
/// has either been answered or explicitly declined.
class const QuestionModal({
    super.key,
    required final SesoriQuestionAsked question,
    required final void Function(String requestId, List<ReplyAnswer> answers) onReply,
    required final void Function(String requestId) onReject,
    /// Status-bar inset captured from the presenting context. The modal route
  /// (`useSafeArea: false`) strips the top inset from BOTH `padding` and
  /// `viewPadding` in the sheet's own MediaQuery, so it must be measured
  /// before presenting and threaded through.
  required final double topInset,
  }) extends StatefulWidget {
  /// Opens the question modal as a content-sized bottom sheet and returns a
  /// [Future] that completes when the sheet is dismissed (by answer, reject,
  /// or swipe).
  ///
  /// Presents a [PregoBottomSheet] directly (not via [showPregoBottomSheet])
  /// because the sheet title tracks the question currently being answered.
  static Future<void> show(
    BuildContext context, {
    required SesoriQuestionAsked question,
    required void Function(String requestId, List<ReplyAnswer> answers) onReply,
    required void Function(String requestId) onReject,
    required Stream<bool> isPendingStream,
    required bool Function() isPending,
  }) {
    // Capture before presenting: inside the route the top inset reads as 0.
    final topInset = MediaQuery.paddingOf(context).top;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // PregoBottomSheet paints the rounded surface; keep the route
      // transparent. The sheet caps itself below the status bar.
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => PendingRequestAutoDismiss(
        isPendingStream: isPendingStream,
        isPending: isPending,
        child: QuestionModal(
          question: question,
          onReply: onReply,
          onReject: onReject,
          topInset: topInset,
        ),
      ),
    );
  }

  @override
  State<QuestionModal> createState() => _QuestionModalState();
}

class _QuestionModalState() extends State<QuestionModal> {
  late final List<_QuestionDraft> _drafts;

  /// Index of the question currently being displayed.
  int _currentIndex = 0;

  /// Direction used by the question-page transition: 1 forward, -1 backward.
  int _navigationDirection = 1;

  bool _confirmingRequestDecline = false;

  void _dismissModal() {
    context.pop();
  }

  List<QuestionInfo> get _questions => widget.question.questions;
  int get _totalQuestions => _questions.length;
  QuestionInfo get _currentInfo => _questions[_currentIndex];
  _QuestionDraft get _currentDraft => _drafts[_currentIndex];
  bool get _isLastQuestion => _currentIndex == _totalQuestions - 1;
  bool get _isMultiQuestion => _totalQuestions > 1;
  bool get _allQuestionsResolved => _drafts.every((draft) => draft.resolution != _QuestionResolution.unanswered);

  @override
  void initState() {
    super.initState();
    _drafts = List.generate(_totalQuestions, (index) {
      final draft = _QuestionDraft();
      draft.customFocus.addListener(() => _onCustomFocusChanged(index: index));
      draft.customController.addListener(() => _onCustomTextChanged(index: index));
      return draft;
    });
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onCustomFocusChanged({required int index}) {
    if (!mounted || index != _currentIndex) return;

    final draft = _drafts[index];
    if (draft.customFocus.hasFocus && (!draft.customSelected || draft.isDeclined)) {
      setState(() {
        draft
          ..disposition = _QuestionDisposition.answer
          ..customSelected = true;
        if (!_currentInfo.multiple) {
          draft.selectedLabels.clear();
        }
      });
    }
  }

  void _onCustomTextChanged({required int index}) {
    // Rebuild to update submit button enabled state.
    if (mounted && index == _currentIndex && _drafts[index].customSelected) {
      setState(() {});
    }
  }

  void _onCustomTileTap() {
    final draft = _currentDraft;
    if (draft.customSelected && !draft.isDeclined) {
      draft.customFocus.unfocus();
      setState(() {
        draft.customSelected = false;
      });
      return;
    }

    setState(() {
      draft
        ..disposition = _QuestionDisposition.answer
        ..customSelected = true;
      if (!_currentInfo.multiple) {
        draft.selectedLabels.clear();
      }
    });
    draft.customFocus.requestFocus();
  }

  void _onOptionTap({required String label}) {
    final draft = _currentDraft;
    draft.customFocus.unfocus();
    setState(() {
      final wasDeclined = draft.isDeclined;
      draft.disposition = _QuestionDisposition.answer;
      if (wasDeclined) {
        if (_currentInfo.multiple) {
          draft.selectedLabels.add(label);
        } else {
          draft
            ..customSelected = false
            ..selectedLabels.clear();
          draft.selectedLabels.add(label);
        }
        return;
      }
      if (_currentInfo.multiple) {
        if (draft.selectedLabels.contains(label)) {
          draft.selectedLabels.remove(label);
        } else {
          draft.selectedLabels.add(label);
        }
      } else {
        draft.customSelected = false;
        // Single-select: toggle — only one at a time.
        if (draft.selectedLabels.contains(label)) {
          draft.selectedLabels.clear();
        } else {
          draft.selectedLabels
            ..clear()
            ..add(label);
        }
      }
    });
  }

  void _onDeclineCurrentQuestion() {
    final draft = _currentDraft;
    draft.customFocus.unfocus();
    setState(() {
      if (draft.isDeclined) {
        draft.disposition = _QuestionDisposition.answer;
        return;
      }
      draft
        ..disposition = _QuestionDisposition.declined
        ..customSelected = false
        ..selectedLabels.clear();
    });
  }

  void _navigateTo({required int index}) {
    if (index == _currentIndex || index < 0 || index >= _totalQuestions) return;

    _currentDraft.customFocus.unfocus();
    setState(() {
      _navigationDirection = index > _currentIndex ? 1 : -1;
      _currentIndex = index;
    });
  }

  void _onProceed() {
    if (!_isLastQuestion) _navigateTo(index: _currentIndex + 1);
  }

  void _onSubmit() {
    if (!_allQuestionsResolved) return;

    final answers = _drafts.map((draft) => ReplyAnswer(values: draft.answerValues)).toList(growable: false);
    widget.onReply(widget.question.id, answers);
    _dismissModal();
  }

  void _onReject() {
    widget.onReject(widget.question.id);
    _dismissModal();
  }

  void _onDeclineRequest() {
    _currentDraft.customFocus.unfocus();
    if (!_isMultiQuestion) {
      _onReject();
      return;
    }

    setState(() => _confirmingRequestDecline = true);
  }

  void _cancelDeclineRequest() {
    setState(() => _confirmingRequestDecline = false);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final info = _currentInfo;
    final draft = _currentDraft;
    final screenHeight = MediaQuery.heightOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Mirror the inset PregoBottomSheet adds below the body so the cap below
    // leaves the pinned action row on screen (including above the keyboard
    // while typing a custom answer).
    final bottomInset = keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom;
    // Size to content: a short question set wraps; a tall one caps just under
    // the sheet's own cap and scrolls inside the Flexible list while the
    // actions stay pinned.
    final maxBody = screenHeight - widget.topInset - PregoBottomSheet.contentTopInset - bottomInset;
    // In a compact landscape/keyboard viewport, the header still provides Back
    // navigation. Let the question content keep the limited vertical space
    // instead of overflowing fixed navigator and helper rows.
    final showQuestionNavigator = _isMultiQuestion && maxBody >= 180;

    return PopScope(
      canPop: !_confirmingRequestDecline,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _confirmingRequestDecline) _cancelDeclineRequest();
      },
      child: PregoBottomSheet(
        title: _confirmingRequestDecline
            ? loc.questionModalDeclineAllTitle
            : (info.header.isNotEmpty ? info.header : loc.questionModalTitle),
        subtitle: _isMultiQuestion && !_confirmingRequestDecline
            ? loc.questionModalStepIndicator(
                _currentIndex + 1,
                _totalQuestions,
              )
            : null,
        topInset: widget.topInset,
        onBack: _confirmingRequestDecline
            ? _cancelDeclineRequest
            : (_currentIndex > 0 ? () => _navigateTo(index: _currentIndex - 1) : null),
        onClose: _dismissModal,
        // Full-bleed body; the step indicator, list, and actions pad themselves.
        contentPadding: EdgeInsetsDirectional.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(maxBody, screenHeight * 0.3)),
          child: _confirmingRequestDecline
              ? _DeclineAllConfirmation(
                  onCancel: _cancelDeclineRequest,
                  onConfirm: _onReject,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Direct question navigation (only when there are multiple questions).
                    if (showQuestionNavigator)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                        child: _QuestionNavigator(
                          currentIndex: _currentIndex,
                          resolutions: _drafts.map((item) => item.resolution).toList(growable: false),
                          onSelected: (index) => _navigateTo(index: index),
                        ),
                      ),

                    // Scrollable body — wraps its content (a handful of option tiles,
                    // so laying them all out is cheap) and scrolls only once the
                    // sheet hits its cap.
                    Flexible(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_currentIndex),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(_navigationDirection * 12 * (1 - value), 0),
                              child: child,
                            ),
                          );
                        },
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Question text
                            MarkdownBody(
                              data: info.question,
                              selectable: true,
                              onTapLink: handleMarkdownLinkTap,
                              styleSheet: buildSessionMarkdownStyleSheet(
                                prego: prego,
                                paragraphStyle: prego.textTheme.textSm.medium,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Option tiles
                            ...info.options.map(
                              (option) => _OptionTile(
                                option: option,
                                isMultiple: info.multiple,
                                isSelected: !draft.isDeclined && draft.selectedLabels.contains(option.label),
                                onTap: () => _onOptionTap(label: option.label),
                              ),
                            ),

                            // Custom answer tile
                            if (info.custom) ...[
                              const SizedBox(height: 8),
                              _CustomAnswerTile(
                                controller: draft.customController,
                                focusNode: draft.customFocus,
                                isSelected: !draft.isDeclined && draft.customSelected,
                                isMultiple: info.multiple,
                                onTap: _onCustomTileTap,
                              ),
                            ],

                            if (_isMultiQuestion) ...[
                              const SizedBox(height: 8),
                              _DeclineQuestionTile(
                                isSelected: draft.isDeclined,
                                onTap: _onDeclineCurrentQuestion,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (_isLastQuestion && !_allQuestionsResolved && showQuestionNavigator)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                        child: Text(
                          loc.questionModalResolveAll,
                          textAlign: TextAlign.center,
                          style: prego.textTheme.textXs.regular.copyWith(
                            color: prego.colors.textSecondary,
                          ),
                        ),
                      ),

                    // Request-wide decline / Submit / Next actions.
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key("decline-question-request"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: prego.colors.fgErrorPrimary,
                                side: BorderSide(color: prego.colors.fgErrorPrimary),
                              ),
                              onPressed: _onDeclineRequest,
                              child: Text(
                                _isMultiQuestion ? loc.questionModalDeclineAll : loc.questionModalDecline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              key: const Key("question-primary-action"),
                              onPressed: _isLastQuestion ? (_allQuestionsResolved ? _onSubmit : null) : _onProceed,
                              child: Text(
                                _isLastQuestion
                                    ? (!_allQuestionsResolved && !showQuestionNavigator
                                          ? loc.questionModalResolveAllCompact
                                          : loc.questionModalSubmit)
                                    : loc.questionModalNext,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

enum _QuestionDisposition() { answer, declined }

enum _QuestionResolution() { unanswered, answered, declined }

class _QuestionDraft() {
  final TextEditingController customController = TextEditingController();
  final FocusNode customFocus = FocusNode();
  final Set<String> selectedLabels = {};

  _QuestionDisposition disposition = _QuestionDisposition.answer;
  bool customSelected = false;

  bool get isDeclined => disposition == _QuestionDisposition.declined;

  List<String> get answerValues {
    if (isDeclined) return const [];

    final values = selectedLabels.toList();
    final custom = customController.text.trim();
    if (customSelected && custom.isNotEmpty) values.add(custom);
    return values;
  }

  _QuestionResolution get resolution {
    if (isDeclined) return _QuestionResolution.declined;
    final hasCustomAnswer = customSelected && customController.text.trim().isNotEmpty;
    return selectedLabels.isEmpty && !hasCustomAnswer ? _QuestionResolution.unanswered : _QuestionResolution.answered;
  }

  void dispose() {
    customFocus.dispose();
    customController.dispose();
  }
}

// -----------------------------------------------------------------------------
// Request-wide decline confirmation
// -----------------------------------------------------------------------------

class const _DeclineAllConfirmation({
    required final VoidCallback onCancel,
    required final VoidCallback onConfirm,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.questionModalDeclineAllMessage,
            style: prego.textTheme.textSm.regular.copyWith(
              color: prego.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: Text(loc.questionModalKeepAnswering),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: prego.colors.fgErrorPrimary,
                  ),
                  onPressed: onConfirm,
                  child: Text(loc.questionModalDeclineAll),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Question navigator
// -----------------------------------------------------------------------------

class const _QuestionNavigator({
    required final int currentIndex,
    required final List<_QuestionResolution> resolutions,
    required final ValueChanged<int> onSelected,
  }) extends StatefulWidget {
  @override
  State<_QuestionNavigator> createState() => _QuestionNavigatorState();
}

class _QuestionNavigatorState() extends State<_QuestionNavigator> {
  late List<GlobalKey> _stepKeys;

  @override
  void initState() {
    super.initState();
    _stepKeys = _buildStepKeys();
  }

  @override
  void didUpdateWidget(covariant _QuestionNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolutions.length != widget.resolutions.length) {
      _stepKeys = _buildStepKeys();
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrentStep());
    }
  }

  List<GlobalKey> _buildStepKeys() => List.generate(widget.resolutions.length, (_) => GlobalKey());

  void _revealCurrentStep() {
    if (!mounted) return;
    final stepContext = _stepKeys[widget.currentIndex].currentContext;
    if (stepContext == null) return;
    Scrollable.ensureVisible(
      stepContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var index = 0; index < widget.resolutions.length; index++) {
      if (index > 0) {
        children.add(
          Container(
            width: 20,
            height: 2,
            color: context.prego.colors.borderSecondary,
          ),
        );
      }
      children.add(
        KeyedSubtree(
          key: _stepKeys[index],
          child: _QuestionStep(
            key: Key("question-step-$index"),
            index: index,
            total: widget.resolutions.length,
            isCurrent: index == widget.currentIndex,
            resolution: widget.resolutions[index],
            onTap: () => widget.onSelected(index),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

class const _QuestionStep({
    super.key,
    required final int index,
    required final int total,
    required final bool isCurrent,
    required final _QuestionResolution resolution,
    required final VoidCallback onTap,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final status = switch (resolution) {
      _QuestionResolution.unanswered => loc.questionModalStatusUnanswered,
      _QuestionResolution.answered => loc.questionModalStatusAnswered,
      _QuestionResolution.declined => loc.questionModalStatusDeclined,
    };
    final backgroundColor = isCurrent
        ? prego.colors.bgBrandSolid
        : switch (resolution) {
            _QuestionResolution.unanswered => prego.colors.bgSurface1,
            _QuestionResolution.answered => prego.colors.bgBrandPrimary,
            _QuestionResolution.declined => prego.colors.bgQuaternary,
          };
    final foregroundColor = isCurrent
        ? prego.colors.textWhite
        : switch (resolution) {
            _QuestionResolution.unanswered => prego.colors.textSecondary,
            _QuestionResolution.answered => prego.colors.textBrandPrimary,
            _QuestionResolution.declined => prego.colors.textSecondary,
          };
    final borderColor = isCurrent
        ? prego.colors.bgBrandSolid
        : switch (resolution) {
            _QuestionResolution.unanswered => prego.colors.borderSecondary,
            _QuestionResolution.answered => prego.colors.borderBrand,
            _QuestionResolution.declined => prego.colors.borderPrimary,
          };

    final child = isCurrent
        ? Text(
            "${index + 1}",
            style: prego.textTheme.textSm.bold.copyWith(color: foregroundColor),
          )
        : switch (resolution) {
            _QuestionResolution.unanswered => Text(
              "${index + 1}",
              style: prego.textTheme.textSm.bold.copyWith(color: foregroundColor),
            ),
            _QuestionResolution.answered => Icon(
              TablerRegular.check,
              size: 16,
              color: foregroundColor,
            ),
            _QuestionResolution.declined => Icon(
              TablerRegular.minus,
              size: 16,
              color: foregroundColor,
            ),
          };

    return Semantics(
      button: true,
      selected: isCurrent,
      label: loc.questionModalStepSemantics(index + 1, total, status),
      onTap: onTap,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Option tile
// -----------------------------------------------------------------------------

class const _OptionTile({
    required final QuestionOption option,
    required final bool isMultiple,
    required final bool isSelected,
    required final VoidCallback onTap,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Material(
        // bgSurface1 so the card reads as raised against the sheet's
        // bgSecondary surface (bgSecondary here would vanish into it).
        color: isSelected ? prego.colors.bgBrandPrimary : prego.colors.bgSurface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isMultiple
                      ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                      : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  color: isSelected ? prego.colors.bgBrandSolid : prego.colors.borderPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        option.label,
                        style: prego.textTheme.textSm.bold.copyWith(
                          fontWeight: .bold,
                        ),
                      ),
                      if (option.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.description,
                          style: prego.textTheme.textXs.regular.copyWith(
                            color: prego.colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Per-question decline tile
// -----------------------------------------------------------------------------

class const _DeclineQuestionTile({
    required final bool isSelected,
    required final VoidCallback onTap,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        key: const Key("decline-current-question"),
        color: isSelected ? prego.colors.bgQuaternary : prego.colors.bgSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? prego.colors.borderPrimary : prego.colors.borderSecondary,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  TablerRegular.circle_minus,
                  color: prego.colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSelected ? loc.questionModalQuestionDeclined : loc.questionModalDeclineQuestion,
                        style: prego.textTheme.textSm.bold.copyWith(
                          color: isSelected ? prego.colors.textPrimary : prego.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSelected ? loc.questionModalQuestionDeclinedHint : loc.questionModalDeclineQuestionHint,
                        style: prego.textTheme.textXs.regular.copyWith(
                          color: prego.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom answer tile
// -----------------------------------------------------------------------------

class const _CustomAnswerTile({
    required final TextEditingController controller,
    required final FocusNode focusNode,
    required final bool isSelected,
    required final bool isMultiple,
    required final VoidCallback onTap,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Material(
        // bgSurface1 so the card reads as raised against the sheet's
        // bgSecondary surface (bgSecondary here would vanish into it).
        color: isSelected ? prego.colors.bgBrandPrimary : prego.colors.bgSurface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Padding(
                  key: const Key("custom-answer-toggle"),
                  padding: const EdgeInsetsDirectional.only(top: 10),
                  child: Icon(
                    isMultiple
                        ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                        : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    color: isSelected ? prego.colors.bgBrandSolid : prego.colors.borderPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: loc.questionModalCustomHint,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
