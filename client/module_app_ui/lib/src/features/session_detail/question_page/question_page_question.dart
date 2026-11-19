import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../file_preview/file_reference_code_syntax.dart";
import "../session_detail_markdown_link_handler.dart";
import "../widgets/request_option_tile.dart";
import "question_page_image.dart";

/// Images in a page's text box are this tall at most.
const questionPageImageMaxHeight = 420.0;
const _optionImageMaxHeight = 160.0;
const _issueDuration = Duration(milliseconds: 200);

/// What Submit found wrong with one question.
enum QuestionPageIssue() {
  /// A required question has no answer.
  needsAnswer,

  /// The bridge refused the answer it was given.
  refused,
}

/// Agent-written Markdown in the chat's styles. Images in it render nothing,
/// so the page never loads from the network; the agent shows images through
/// the page's own image fields. Links open only when tapped.
class const QuestionPageMarkdown({super.key, required final String data}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onTapLink = buildSessionDetailMarkdownLinkTapHandler(context: context);
    return MarkdownBody(
      data: data,
      selectable: false,
      onTapLink: onTapLink,
      imageBuilder: (_, _, _) => const SizedBox.shrink(),
      styleSheet: buildChatMessageMarkdownStyleSheet(prego: context.prego),
      blockSyntaxes: sessionMarkdownBlockSyntaxes,
      inlineSyntaxes: sessionMarkdownInlineSyntaxes,
      builders: buildSessionMarkdownBuilders(
        highlightEnabled: true,
        copyTooltip: context.loc.sessionDetailCopy,
        onTapLink: onTapLink,
      ),
    );
  }
}

/// A free-text box styled like the question sheet's own answer box. Disabled
/// on a read-only page, where it keeps its text.
class const QuestionPageTextField({
  super.key,
  required final TextEditingController controller,
  required final String hint,
  required final bool enabled,
  required final bool isFlagged,
  required final int minLines,
  required final ValueChanged<String> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSecondary,
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        border: Border.all(color: isFlagged ? prego.colors.borderError : prego.colors.borderSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: 8,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          decoration: InputDecoration(hintText: hint, border: InputBorder.none, isCollapsed: true),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// One question: its title, text and images, then the control its kind needs,
/// and for a choice question a note.
class const QuestionPageQuestion({
  super.key,
  required final PageQuestion question,
  required final PageAnswer? answer,
  required final bool enabled,
  required final QuestionPageIssue? issue,

  /// The text question's answer box.
  required final TextEditingController answerController,

  /// The choice question's note.
  required final TextEditingController noteController,

  /// Whether the choice question shows its note row. A read-only page hides
  /// an empty note; a submitting page keeps it so nothing below moves.
  required final bool showsNote,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final cubit = context.read<PendingPageCubit>();
    final body = question.body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: PregoSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(question.title, style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary)),
            if (question.isRequired)
              Text(
                loc.questionPageRequired,
                style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
              ),
          ],
        ),
        // The reason grows in below the title, so the question it explains
        // stays where Submit scrolled it.
        AnimatedSize(
          duration: context.isReducedMotion ? Duration.zero : _issueDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (issue) {
            final issue? => Padding(
              padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  switch (issue) {
                    QuestionPageIssue.needsAnswer => loc.questionPageNeedsAnswer,
                    QuestionPageIssue.refused => loc.questionPageAnswerRefused,
                  },
                  key: Key("question-page-issue-${question.id}"),
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textErrorPrimary),
                ),
              ),
            ),
            null => const SizedBox(width: double.infinity),
          },
        ),
        if (body != null) ...[const SizedBox(height: PregoSpacing.sm), QuestionPageMarkdown(data: body)],
        for (final image in question.images) ...[
          const SizedBox(height: PregoSpacing.md),
          QuestionPageImage(image: image, maxHeight: questionPageImageMaxHeight),
        ],
        const SizedBox(height: PregoSpacing.lg),
        switch (question.kind) {
          PageSingleChoice(:final options) => _Options(
            options: options,
            isMultiple: false,
            selected: switch (answer?.value) {
              PageChoiceAnswer(:final optionId) => {optionId},
              _ => const {},
            },
            enabled: enabled,
            // Tapping the picked option clears it, so an optional question can
            // go back to unanswered.
            onTap: ({required optionId, required isSelected}) =>
                cubit.setChoice(questionId: question.id, optionId: isSelected ? null : optionId),
          ),
          PageMultipleChoice(:final options) => _Options(
            options: options,
            isMultiple: true,
            selected: switch (answer?.value) {
              PageChoicesAnswer(:final optionIds) => optionIds.toSet(),
              _ => const {},
            },
            enabled: enabled,
            onTap: ({required optionId, required isSelected}) {
              final picked = switch (answer?.value) {
                PageChoicesAnswer(:final optionIds) => optionIds,
                _ => const <String>[],
              };
              // Kept in the options' order, whatever order they were tapped in.
              final next = {...picked, optionId};
              if (isSelected) next.remove(optionId);
              cubit.setChoices(
                questionId: question.id,
                optionIds: [
                  for (final option in options)
                    if (next.contains(option.id)) option.id,
                ],
              );
            },
          ),
          PageTextInput() => QuestionPageTextField(
            key: Key("question-page-answer-${question.id}"),
            controller: answerController,
            hint: enabled ? loc.questionPageAnswerHint : loc.questionPageNoAnswer,
            enabled: enabled,
            isFlagged: issue != null,
            minLines: 3,
            onChanged: (text) => cubit.setText(questionId: question.id, text: text),
          ),
          PageQuestionKindUnknown() => Text(
            loc.questionPageUnsupportedQuestion,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textTertiary),
          ),
        },
        // The row folds away when the page settles while open.
        if (question.kind case PageSingleChoice() || PageMultipleChoice())
          AnimatedSize(
            duration: context.isReducedMotion ? Duration.zero : _issueDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showsNote
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(top: PregoSpacing.xs),
                    child: QuestionPageTextField(
                      key: Key("question-page-note-${question.id}"),
                      controller: noteController,
                      hint: loc.questionPageNoteHint,
                      enabled: enabled,
                      isFlagged: false,
                      minLines: 1,
                      onChanged: (note) => cubit.setQuestionNote(questionId: question.id, note: note),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

class const _Options({
  required final List<PageOption> options,
  required final bool isMultiple,
  required final Set<String> selected,
  required final bool enabled,
  required final void Function({required String optionId, required bool isSelected}) onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          RequestOptionTile(
            key: Key("question-page-option-${option.id}"),
            label: option.label,
            description: option.description,
            isMultiple: isMultiple,
            isSelected: selected.contains(option.id),
            onTap: enabled ? () => onTap(optionId: option.id, isSelected: selected.contains(option.id)) : null,
            badge: option.recommended
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: prego.colors.bgBrandSecondary,
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: 1),
                      child: Text(
                        context.loc.questionPageRecommended,
                        style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textBrandSecondary),
                      ),
                    ),
                  )
                : null,
            footer: switch (option.image) {
              final image? => QuestionPageImage(image: image, maxHeight: _optionImageMaxHeight),
              null => null,
            },
          ),
      ],
    );
  }
}
