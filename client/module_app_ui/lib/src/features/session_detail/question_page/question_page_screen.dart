import "dart:math" as math;

import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../session_detail_presentation_scope.dart";
import "question_page_question.dart";

typedef PendingPageCubitFactory = PendingPageCubit Function({required String requestId, required String sessionId});

const _openDuration = Duration(milliseconds: 320);
const _closeDuration = Duration(milliseconds: 240);
const _contentDuration = Duration(milliseconds: 200);
const _scrollDuration = Duration(milliseconds: 320);
const _headerHeight = 52.0;
const _barHeight = 64.0;

/// From this window width the page opens as a wide overlay over the session
/// rather than covering it.
const _wideOverlayMinWidth = 960.0;
const _wideOverlayGap = PregoSpacing.x4l;

/// Slides the page [requestId] up over the session, whether it waits for an
/// answer or has settled: its cubit's lookup decides how it opens. Its cubit
/// comes from [scope] and lives as long as the route. The page names the
/// session [context] shows as its source. Open it through
/// [SessionDetailPresentationScope.openPage].
Future<void> showQuestionPage({
  required BuildContext context,
  required SessionDetailPresentationScope scope,
  required String requestId,
  required String sessionId,
}) {
  final source = switch (context.read<SessionDetailCubit>().state.hydratedSession) {
    final session? => [PregoBrandLogo.displayNameFor(session.pluginId), ?session.title].join(" · "),
    null => null,
  };
  final reducedMotion = context.isReducedMotion;
  // ignore: no_slop_linter/avoid_navigator_of, the page is a transient route over the session page
  final navigator = Navigator.of(context);
  final route = PageRouteBuilder<void>(
    // The session stays drawn below: the wide overlay shows it around the page.
    opaque: false,
    transitionDuration: reducedMotion ? Duration.zero : _openDuration,
    reverseTransitionDuration: reducedMotion ? Duration.zero : _closeDuration,
    pageBuilder: (_, _, _) => scope.around(
      openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {
        navigator.pop();
        scope.openSession(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly);
      },
      child: BlocProvider(
        create: (_) => scope.createPendingPageCubit(requestId: requestId, sessionId: sessionId),
        child: QuestionPageScreen(source: source, onClose: navigator.pop),
      ),
    ),
    transitionsBuilder: (_, animation, _, child) => _QuestionPageFrame(
      animation: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      onClose: navigator.pop,
      child: child,
    ),
  );
  // ignore: no_slop_linter/avoid_raw_go_router, the page carries an in-memory cubit that cannot be represented in a URL
  return navigator.push<void>(route);
}

/// Slides the page up from the bottom edge: over the whole session on a
/// narrow window, or as a wide panel over a dimmed session on a wide one.
class const _QuestionPageFrame({
  required final Animation<double> animation,
  required final VoidCallback onClose,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideOverlayMinWidth) {
          return SlideTransition(position: slide, child: child);
        }
        final top = math.max(_wideOverlayGap, MediaQuery.paddingOf(context).top + PregoSpacing.lg);
        return Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: animation,
              child: GestureDetector(
                key: const Key("question-page-scrim"),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.14),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(top: top),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: PregoModalWidth.code.pixels,
                  child: SlideTransition(
                    position: slide,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(PregoRadius.x3l)),
                      // The panel sits below the status bar, so its header
                      // needs no room for it.
                      child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An agent's question page: its title and source in a fixed header, its
/// sections in a scrolling body, and a sticky bar with the progress and
/// Submit. A settled page is the same screen with its controls disabled, so
/// one settling while open changes nothing on screen but the bar.
class const QuestionPageScreen({
  super.key,

  /// The session the page came from, such as "Claude Code · Fix the login".
  required final String? source,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<QuestionPageScreen> createState() => _QuestionPageScreenState();
}

class _QuestionPageScreenState() extends State<QuestionPageScreen> {
  final _scroll = ScrollController();
  final _questionKeys = <String, GlobalKey>{};
  final _answerFields = <String, TextEditingController>{};
  final _noteFields = <String, TextEditingController>{};
  TextEditingController? _closingNote;

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in [..._answerFields.values, ..._noteFields.values, ?_closingNote]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The field's controller, made on first use with the draft's text, which
  /// the field then owns.
  TextEditingController _field({
    required Map<String, TextEditingController> fields,
    required String questionId,
    required String? text,
  }) => fields[questionId] ??= TextEditingController(text: text);

  /// Brings the first question Submit flagged into view.
  void _scrollToIssue({required List<String> questionIds}) {
    final target = switch (questionIds.firstOrNull) {
      final id? => _questionKeys[id]?.currentContext,
      null => null,
    };
    if (target == null) return;
    FocusScope.of(context).unfocus();
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: context.isReducedMotion ? Duration.zero : _scrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final state = context.watch<PendingPageCubit>().state;
    final page = switch (state) {
      PageEditing(:final page) || PageSubmitting(:final page) || PageReadOnly(:final page) => page,
      PageLoading() || PageMissing() || PageUnsupported() || PageLoadFailed() => null,
    };
    return BlocListener<PendingPageCubit, PendingPageState>(
      listenWhen: (previous, current) =>
          previous is PageSubmitting && current is PageEditing && current.feedback is PageFeedbackInvalid,
      listener: (_, state) {
        if (state case PageEditing(feedback: PageFeedbackInvalid(:final questionIds))) {
          _scrollToIssue(questionIds: questionIds);
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  title: page?.title,
                  source: widget.source,
                  onClose: widget.onClose,
                  onDismiss: switch (state) {
                    PageEditing() => context.read<PendingPageCubit>().dismiss,
                    _ => null,
                  },
                  showsMenu: state is PageEditing || state is PageSubmitting,
                ),
                Divider(height: 1, thickness: 1, color: prego.colors.borderSecondary),
                Expanded(
                  // Page content stays below the header, whatever it holds.
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: context.isReducedMotion ? Duration.zero : _contentDuration,
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        children: [...previous, ?current],
                      ),
                      child: KeyedSubtree(
                        // Every state that shows the page shares one key, so
                        // settling or submitting never rebuilds it.
                        key: ValueKey(page == null ? state.runtimeType : PendingPage),
                        child: switch (state) {
                          PageLoading() => const Center(child: PregoActivityIndicator(color: null)),
                          PageMissing() => _Message(text: context.loc.questionPageMissing, onRetry: null),
                          PageUnsupported() => _Message(text: context.loc.questionPageUnsupported, onRetry: null),
                          PageLoadFailed() => _Message(
                            text: context.loc.questionPageLoadFailed,
                            onRetry: context.read<PendingPageCubit>().retry,
                          ),
                          PageEditing(:final page, :final draft) ||
                          PageSubmitting(:final page, :final draft) ||
                          PageReadOnly(:final page, :final draft) => _PageBody(
                            page: page,
                            draft: draft,
                            state: state,
                            scroll: _scroll,
                            questionKeys: _questionKeys,
                            answerField: (id) => _field(
                              fields: _answerFields,
                              questionId: id,
                              text: switch (draft.answers[id]?.value) {
                                PageTextAnswer(:final text) => text,
                                _ => null,
                              },
                            ),
                            noteField: (id) =>
                                _field(fields: _noteFields, questionId: id, text: draft.answers[id]?.note),
                            closingNote: _closingNote ??= TextEditingController(text: draft.note),
                          ),
                        },
                      ),
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

class const _Header({
  required final String? title,
  required final String? source,
  required final VoidCallback onClose,

  /// Null while the page can't be dismissed, such as during a submit.
  required final VoidCallback? onDismiss,
  required final bool showsMenu,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final padding = MediaQuery.paddingOf(context);
    final duration = context.isReducedMotion ? Duration.zero : _contentDuration;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      constraints: BoxConstraints(minHeight: padding.top + _headerHeight),
      padding: EdgeInsetsDirectional.only(top: padding.top, start: PregoSpacing.xs, end: PregoSpacing.sm),
      alignment: Alignment.center,
      child: Row(
        children: [
          IconButton(
            key: const Key("question-page-close"),
            tooltip: loc.questionPageClose,
            icon: const Icon(TablerRegular.chevron_down, size: PregoIconSize.md),
            // Like the back button on the app's other screens. Set here because
            // the phone theme leaves icon buttons Material's colour.
            style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(prego.colors.textPrimary)),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The title fades in once the page has loaded.
                AnimatedSwitcher(
                  duration: duration,
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                  child: switch (title) {
                    final title? => Text(
                      title,
                      key: ValueKey(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
                    ),
                    null => const SizedBox.shrink(),
                  },
                ),
                if (source case final source?)
                  Text(
                    loc.questionPageSource(source),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: duration,
            child: showsMenu
                ? PregoAnchorMenu(
                    key: const Key("question-page-menu"),
                    flat: true,
                    placement: PregoMenuPlacement.belowRightAligned,
                    entriesBuilder: () => [
                      PregoMenuItem(
                        key: const Key("question-page-dismiss"),
                        title: loc.questionPageDismiss,
                        subtitle: null,
                        isSelected: false,
                        isEnabled: onDismiss != null,
                        leadingIcon: TablerRegular.circle_x,
                        shortcutLabel: null,
                        onTap: () => onDismiss?.call(),
                      ),
                    ],
                    triggerBuilder: (context, openMenu) => PregoButtonsSolid.iconOnly(
                      leadingIcon: TablerRegular.dots,
                      semanticLabel: loc.questionPageActions,
                      showsTooltip: true,
                      hierarchy: PregoButtonsSolidHierarchy.tertiary,
                      size: PregoButtonsSolidSize.sm,
                      onPressed: openMenu,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class const _Message({required final String text, required final VoidCallback? onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              key: const Key("question-page-message"),
              textAlign: TextAlign.center,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: PregoSpacing.lg),
              PregoButtonsSolid(
                label: context.loc.questionPageRetry,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.md,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class const _PageBody({
  required final PendingPage page,
  required final PageDraft draft,
  required final PendingPageState state,
  required final ScrollController scroll,
  required final Map<String, GlobalKey> questionKeys,
  required final TextEditingController Function(String questionId) answerField,
  required final TextEditingController Function(String questionId) noteField,
  required final TextEditingController closingNote,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final cubit = context.read<PendingPageCubit>();
    final enabled = state is PageEditing;
    final flagged = switch (state) {
      PageEditing(feedback: PageFeedbackInvalid(:final questionIds)) => questionIds.toSet(),
      _ => const <String>{},
    };
    final intro = page.intro;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(PregoSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(page.title, style: prego.textTheme.textXl.medium.copyWith(color: prego.colors.textPrimary)),
                if (intro != null) ...[const SizedBox(height: PregoSpacing.md), QuestionPageMarkdown(data: intro)],
                for (final section in page.sections) ...[
                  const SizedBox(height: PregoSpacing.x3l),
                  if (section.heading case final heading?) ...[
                    Text(heading, style: prego.textTheme.textLg.bold.copyWith(color: prego.colors.textPrimary)),
                    const SizedBox(height: PregoSpacing.md),
                  ],
                  if (section.body case final body?) ...[
                    QuestionPageMarkdown(data: body),
                    const SizedBox(height: PregoSpacing.md),
                  ],
                  for (final question in section.questions) ...[
                    const SizedBox(height: PregoSpacing.lg),
                    QuestionPageQuestion(
                      key: questionKeys[question.id] ??= GlobalKey(debugLabel: "question-page-${question.id}"),
                      question: question,
                      answer: draft.answers[question.id],
                      enabled: enabled,
                      issue: switch ((flagged.contains(question.id), draft.answers[question.id]?.value)) {
                        (false, _) => null,
                        (true, null) => QuestionPageIssue.needsAnswer,
                        (true, _) => QuestionPageIssue.refused,
                      },
                      answerController: answerField(question.id),
                      noteController: noteField(question.id),
                    ),
                  ],
                ],
                const SizedBox(height: PregoSpacing.x4l),
                Text(
                  loc.questionPageClosingNoteTitle,
                  style: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
                ),
                const SizedBox(height: PregoSpacing.md),
                QuestionPageTextField(
                  key: const Key("question-page-closing-note"),
                  controller: closingNote,
                  hint: enabled ? loc.questionPageClosingNoteHint : loc.questionPageNoNote,
                  enabled: enabled,
                  isFlagged: false,
                  minLines: 2,
                  onChanged: (note) => cubit.setNote(note: note),
                ),
              ],
            ),
          ),
        ),
        _Bar(page: page, draft: draft, state: state, bottomInset: bottomInset),
      ],
    );
  }
}

/// The sticky bar: progress and Submit while the page waits, or how it
/// settled. It keeps one height in every state, so a change never moves the
/// page above it.
class const _Bar({
  required final PendingPage page,
  required final PageDraft draft,
  required final PendingPageState state,
  required final double bottomInset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final cubit = context.read<PendingPageCubit>();
    final questions = [
      for (final section in page.sections)
        for (final question in section.questions)
          if (question.kind is! PageQuestionKindUnknown) question,
    ];
    final answered = questions.where((question) => draft.answers[question.id]?.value != null).length;
    final duration = context.isReducedMotion ? Duration.zero : _contentDuration;
    final settled = switch (state) {
      PageReadOnly(reason: PageReadOnlyReason.answered) => (TablerRegular.circle_check, loc.questionPageAnswered),
      PageReadOnly(reason: PageReadOnlyReason.answeredElsewhere) => (
        TablerRegular.circle_check,
        loc.questionPageAnsweredElsewhere,
      ),
      PageReadOnly(reason: PageReadOnlyReason.dismissed) => (TablerRegular.circle_x, loc.questionPageDismissed),
      _ => null,
    };
    final Widget content;
    if (settled case (final icon, final label)) {
      content = Row(
        key: const ValueKey("settled"),
        children: [
          Icon(icon, size: PregoIconSize.md, color: prego.colors.textSecondary),
          const SizedBox(width: PregoSpacing.md),
          Expanded(
            child: Text(
              label,
              key: const Key("question-page-settled"),
              style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
            ),
          ),
        ],
      );
    } else {
      final status = _status(state: state, loc: loc, answered: answered, total: questions.length);
      content = Row(
        key: const ValueKey("open"),
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: duration,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                child: switch (status) {
                  (:final text, :final isProblem) => Text(
                    text,
                    key: ValueKey(text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textSm.regular.copyWith(
                      color: isProblem ? prego.colors.textErrorPrimary : prego.colors.textSecondary,
                    ),
                  ),
                  null => const SizedBox.shrink(),
                },
              ),
            ),
          ),
          const SizedBox(width: PregoSpacing.lg),
          PregoButtonsSolid(
            key: const Key("question-page-submit"),
            label: questions.isEmpty ? loc.questionPageDone : loc.questionPageSubmit,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            size: PregoButtonsSolidSize.md,
            isLoading: switch (state) {
              PageSubmitting(action: PageAction.submit) => true,
              _ => false,
            },
            onPressed: state is PageEditing ? cubit.submit : null,
          ),
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: prego.colors.borderSecondary)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(PregoSpacing.xl, 0, PregoSpacing.xl, bottomInset),
        child: SizedBox(
          height: _barHeight,
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: (current, previous) =>
                Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
            child: content,
          ),
        ),
      ),
    );
  }

  /// Null on a page with no questions, which has no progress to show.
  static ({String text, bool isProblem})? _status({
    required PendingPageState state,
    required AppLocalizations loc,
    required int answered,
    required int total,
  }) {
    final progress = total == 0 ? null : (text: loc.questionPageProgress(answered, total), isProblem: false);
    return switch (state) {
      PageEditing(feedback: PageFeedbackFailed(action: PageAction.submit)) => (
        text: loc.questionPageSubmitFailed,
        isProblem: true,
      ),
      PageEditing(feedback: PageFeedbackFailed(action: PageAction.dismiss)) => (
        text: loc.questionPageDismissFailed,
        isProblem: true,
      ),
      PageEditing(feedback: PageFeedbackUnknownResult()) => (text: loc.questionPageUnknownResult, isProblem: true),
      PageEditing(feedback: PageFeedbackInvalid(:final questionIds)) when questionIds.isNotEmpty => (
        text: loc.questionPageInvalid(questionIds.length),
        isProblem: true,
      ),
      PageEditing() ||
      PageSubmitting() ||
      PageReadOnly() ||
      PageLoading() ||
      PageMissing() ||
      PageUnsupported() ||
      PageLoadFailed() => progress,
    };
  }
}
