import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_shared/sesori_shared.dart";

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
  final void Function(String requestId, List<String> answers) onReply;
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
    required void Function(String requestId, List<String> answers) onReply,
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
  final List<String> _collectedAnswers = [];

  /// Selection state for the *current* question.
  final Set<String> _selectedLabels = {};
  bool _customSelected = false;

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
        _selectedLabels.clear();
      });
    }
  }

  void _onCustomTextChanged() {
    // Rebuild to update submit button enabled state.
    if (_customSelected) setState(() {});
  }

  void _onCustomTileTap() {
    setState(() {
      _customSelected = true;
      _selectedLabels.clear();
    });
    _customFocus.requestFocus();
  }

  void _onOptionTap(String label) {
    _customFocus.unfocus();
    setState(() {
      _customSelected = false;
      if (_currentInfo.multiple) {
        if (_selectedLabels.contains(label)) {
          _selectedLabels.remove(label);
        } else {
          _selectedLabels.add(label);
        }
      } else {
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

  bool get _canProceed {
    if (_customSelected) return _customController.text.trim().isNotEmpty;
    return _selectedLabels.isNotEmpty;
  }

  /// Collects the current answer and either advances to the next question
  /// or submits all answers if this is the last one.
  void _onProceed() {
    // Build the answer for the current question.
    final List<String> answer;
    if (_customSelected) {
      final text = _customController.text.trim();
      if (text.isEmpty) return;
      answer = [text];
    } else {
      if (_selectedLabels.isEmpty) return;
      answer = _selectedLabels.toList();
    }

    _collectedAnswers.addAll(answer);

    if (_isLastQuestion) {
      // All questions answered — submit.
      widget.onReply(widget.question.id, _collectedAnswers);
      Navigator.of(context).pop();
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
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    final info = _currentInfo;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.header.isNotEmpty ? info.header : loc.questionModalTitle,
                    style: theme.textTheme.titleMedium,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    loc.questionModalStepIndicator(
                      _currentIndex + 1,
                      _totalQuestions,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _totalQuestions,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.primary,
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
                  styleSheet: buildSessionMarkdownStyleSheet(
                    theme,
                    paragraphStyle: theme.textTheme.bodyLarge,
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
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
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        option.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                      ),
                      if (option.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerLow,
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
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(
                    isMultiple
                        ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                        : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
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
