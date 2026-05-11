import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

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
    final zyra = context.zyra;
    final loc = context.loc;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    final info = _currentInfo;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: zyra.colors.bgPrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
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
                color: zyra.colors.borderSecondary,
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
                  color: zyra.colors.bgBrandSolid,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.header.isNotEmpty ? info.header : loc.questionModalTitle,
                    style: zyra.textTheme.textMd.bold,
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
                    style: zyra.textTheme.textSm.bold.copyWith(
                      color: zyra.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _totalQuestions,
                        minHeight: 4,
                        backgroundColor: zyra.colors.bgQuaternary,
                        color: zyra.colors.bgBrandSolid,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

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
                      zyra: zyra,
                      paragraphStyle: zyra.textTheme.textSm.medium,
                    ),
                ),
                const SizedBox(height: 16),

                // Option tiles
                ...info.options.map(
                  (option) => _OptionTile(
                    option: option,
                    isMultiple: info.multiple,
                    isSelected: _selectedLabels.contains(option.label),
                    onTap: () => _onOptionTap(option.label),
                  ),
                ),

                // Custom answer tile
                if (info.custom) ...[
                  const SizedBox(height: 8),
                  _CustomAnswerTile(
                    controller: _customController,
                    focusNode: _customFocus,
                    isSelected: _customSelected,
                    isMultiple: info.multiple,
                    onTap: _onCustomTileTap,
                  ),
                ],
              ],
            ),
          ),

          // Submit / Next button
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canProceed ? _onProceed : null,
                child: Text(
                  _isLastQuestion ? loc.questionModalSubmit : loc.questionModalNext,
                ),
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
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.isMultiple,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Material(
        color: isSelected ? zyra.colors.bgBrandPrimary : zyra.colors.bgSecondary,
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
                  color: isSelected ? zyra.colors.bgBrandSolid : zyra.colors.borderPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        option.label,
                        style: zyra.textTheme.textSm.bold.copyWith(
                          fontWeight: .bold,
                        ),
                      ),
                      if (option.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.description,
                            style: zyra.textTheme.textXs.regular.copyWith(
                              color: zyra.colors.textSecondary,
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
    final zyra = context.zyra;
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Material(
        color: isSelected ? zyra.colors.bgBrandPrimary : zyra.colors.bgSecondary,
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
                    color: isSelected ? zyra.colors.bgBrandSolid : zyra.colors.borderPrimary,
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
