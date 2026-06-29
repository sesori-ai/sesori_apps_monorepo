import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "../../../core/widgets/markdown_styles.dart";

/// Bottom sheet that presents all server-driven questions within a single
/// [SesoriQuestionAsked] event, one at a time.
///
/// The user steps through each [QuestionInfo] sequentially. Answers are
/// collected locally and only submitted once every question has been answered.
class QuestionModal extends StatefulWidget {
  final SesoriQuestionAsked question;
  final void Function(String requestId, List<ReplyAnswer> answers) onReply;
  final void Function(String requestId) onReject;

  const QuestionModal({
    super.key,
    required this.question,
    required this.onReply,
    required this.onReject,
  });

  /// Opens the question modal as a 70 % bottom sheet and returns a [Future]
  /// that completes when the sheet is dismissed (by answer, reject, or swipe).
  static Future<void> show(
    BuildContext context, {
    required SesoriQuestionAsked question,
    required void Function(String requestId, List<ReplyAnswer> answers) onReply,
    required void Function(String requestId) onReject,
  }) {
    return showAppModalBottomSheet<void>(
      handleBottomSafeArea: false,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuestionModal(
        question: question,
        onReply: onReply,
        onReject: onReject,
      ),
    );
  }

  @override
  State<QuestionModal> createState() => _QuestionModalState();
}

class _QuestionModalState extends State<QuestionModal> {
  final TextEditingController _customController = TextEditingController();
  final FocusNode _customFocus = FocusNode();

  /// Index of the question currently being displayed.
  int _currentIndex = 0;

  /// Answers collected so far — one entry per completed question.
  final List<ReplyAnswer> _collectedAnswers = [];

  /// Selection state for the *current* question.
  final Set<String> _selectedLabels = {};
  bool _customSelected = false;

  void _dismissModal() {
    context.pop();
  }

  List<QuestionInfo> get _questions => widget.question.questions;
  int get _totalQuestions => _questions.length;
  QuestionInfo get _currentInfo => _questions[_currentIndex];
  bool get _isLastQuestion => _currentIndex == _totalQuestions - 1;
  bool get _isMultiQuestion => _totalQuestions > 1;

  @override
  void initState() {
    super.initState();
    _customFocus.addListener(_onCustomFocusChanged);
    _customController.addListener(_onCustomTextChanged);
  }

  @override
  void dispose() {
    _customFocus.dispose();
    _customController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  void _onCustomFocusChanged() {
    if (_customFocus.hasFocus && !_customSelected) {
      setState(() {
        _customSelected = true;
        if (!_currentInfo.multiple) {
          _selectedLabels.clear();
        }
      });
    }
  }

  void _onCustomTextChanged() {
    // Rebuild to update submit button enabled state.
    if (_customSelected) setState(() {});
  }

  void _onCustomTileTap() {
    if (_customSelected) {
      _customFocus.unfocus();
      setState(() {
        _customSelected = false;
      });
      return;
    }

    setState(() {
      _customSelected = true;
      if (!_currentInfo.multiple) {
        _selectedLabels.clear();
      }
    });
    _customFocus.requestFocus();
  }

  void _onOptionTap(String label) {
    _customFocus.unfocus();
    setState(() {
      if (_currentInfo.multiple) {
        if (_selectedLabels.contains(label)) {
          _selectedLabels.remove(label);
        } else {
          _selectedLabels.add(label);
        }
      } else {
        _customSelected = false;
        // Single-select: toggle — only one at a time.
        if (_selectedLabels.contains(label)) {
          _selectedLabels.clear();
        } else {
          _selectedLabels
            ..clear()
            ..add(label);
        }
      }
    });
  }

  String get _trimmedCustomAnswer => _customController.text.trim();
  bool get _hasSelectedCustomAnswer => _customSelected && _trimmedCustomAnswer.isNotEmpty;

  bool get _canProceed {
    return _selectedLabels.isNotEmpty || _hasSelectedCustomAnswer;
  }

  /// Collects the current answer and either advances to the next question
  /// or submits all answers if this is the last one.
  void _onProceed() {
    // Build the answer for the current question.
    final answer = _selectedLabels.toList();
    if (_hasSelectedCustomAnswer) {
      answer.add(_trimmedCustomAnswer);
    }
    if (answer.isEmpty) return;

    _collectedAnswers.add(ReplyAnswer(values: answer));

    if (_isLastQuestion) {
      // All questions answered — submit.
      widget.onReply(widget.question.id, _collectedAnswers);
      _dismissModal();
    } else {
      // Advance to next question — reset selection state.
      setState(() {
        _currentIndex++;
        _selectedLabels.clear();
        _customSelected = false;
        _customController.clear();
      });
    }
  }

  void _onReject() {
    widget.onReject(widget.question.id);
    _dismissModal();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    final info = _currentInfo;

    return GlassContainer(
      height: height,
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      // Round only the top so the sheet still sits flush to the bottom edge.
      shape: const LiquidVerticalRoundedSuperellipse(topRadius: 20, bottomRadius: 0),
      // Frosted but kept fairly opaque: this is a content-heavy modal, so the
      // chat blurs behind its edges without hurting the question's legibility.
      settings: LiquidGlassSettings(
        glassColor: prego.colors.bgPrimary.withValues(alpha: 0.78),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: prego.colors.borderSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20,
                  color: prego.colors.bgBrandSolid,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.header.isNotEmpty ? info.header : loc.questionModalTitle,
                    style: prego.textTheme.textMd.bold,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _onReject,
                  child: Text(loc.questionModalReject),
                ),
              ],
            ),
          ),

          // Step indicator (only when there are multiple questions)
          if (_isMultiQuestion)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    loc.questionModalStepIndicator(
                      _currentIndex + 1,
                      _totalQuestions,
                    ),
                    style: prego.textTheme.textSm.bold.copyWith(
                      color: prego.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _totalQuestions,
                        minHeight: 4,
                        backgroundColor: prego.colors.bgQuaternary,
                        color: prego.colors.bgBrandSolid,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const GlassDivider(),

          // Scrollable body
          Expanded(
            child: ListView(
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

                // Option tiles — a grouped glass list that shares the sheet's
                // frosted layer. Selection is shown by the filled check/radio
                // and a brand-tinted label rather than a filled background.
                for (var i = 0; i < info.options.length; i++)
                  _OptionTile(
                    option: info.options[i],
                    isMultiple: info.multiple,
                    isSelected: _selectedLabels.contains(info.options[i].label),
                    // Suppress the trailing divider only when nothing (no
                    // custom-answer tile) follows this option.
                    isLast: !info.custom && i == info.options.length - 1,
                    onTap: () => _onOptionTap(info.options[i].label),
                  ),

                // Custom answer tile continues the same grouped list.
                if (info.custom)
                  _CustomAnswerTile(
                    controller: _customController,
                    focusNode: _customFocus,
                    isSelected: _customSelected,
                    isMultiple: info.multiple,
                    onTap: _onCustomTileTap,
                  ),
              ],
            ),
          ),

          // Submit / Next button. The sheet runs its glass flush to the bottom
          // edge (handleBottomSafeArea: false), so the home-indicator inset
          // isn't padded for us — add it here to lift the button clear of the
          // indicator. It collapses to 0 while the keyboard is up, which already
          // lifts the whole sheet.
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
            child: GlassButton.custom(
              // `_onProceed` no-ops on an empty answer, so gating via `enabled`
              // is enough — no need to swap the callback when disabled.
              onTap: _onProceed,
              enabled: _canProceed,
              width: double.infinity,
              height: 52,
              useOwnLayer: true,
              shape: const LiquidRoundedSuperellipse(borderRadius: 16),
              settings: LiquidGlassSettings(glassColor: prego.colors.bgBrandSolid),
              child: Text(
                _isLastQuestion ? loc.questionModalSubmit : loc.questionModalNext,
                style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textWhite),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Option tile
// -----------------------------------------------------------------------------

class _OptionTile extends StatelessWidget {
  final QuestionOption option;
  final bool isMultiple;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isMultiple,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return GlassListTile(
      onTap: onTap,
      isLast: isLast,
      leading: Icon(
        isMultiple
            ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
            : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        color: isSelected ? prego.colors.bgBrandSolid : prego.colors.borderPrimary,
      ),
      title: Text(option.label),
      titleStyle: prego.textTheme.textSm.bold.copyWith(
        color: isSelected ? prego.colors.bgBrandSolid : prego.colors.textPrimary,
      ),
      subtitle: option.description.isNotEmpty ? Text(option.description) : null,
      subtitleStyle: prego.textTheme.textXs.regular.copyWith(
        color: prego.colors.textSecondary,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Custom answer tile
// -----------------------------------------------------------------------------

class _CustomAnswerTile extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSelected;
  final bool isMultiple;
  final VoidCallback onTap;

  const _CustomAnswerTile({
    required this.controller,
    required this.focusNode,
    required this.isSelected,
    required this.isMultiple,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    // Rendered as a bare grouped row on the sheet's glass (no own surface) so
    // it continues seamlessly from the option tiles above. The text field
    // can't live inside a GlassListTile, so the row is composed by hand but
    // mirrors the tile's leading-icon + content padding.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                style: prego.textTheme.textSm.regular.copyWith(
                  color: prego.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: loc.questionModalCustomHint,
                  hintStyle: prego.textTheme.textSm.regular.copyWith(
                    color: prego.colors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
