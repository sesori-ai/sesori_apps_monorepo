import "dart:async";
import "dart:math";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../utils/copy_text_to_clipboard.dart";
import "../session_detail/widgets/text_part_widget.dart";
import "../session_detail/widgets/transcript_live_row.dart";

const _fadeDuration = Duration(milliseconds: 200);
const _slideInDuration = Duration(milliseconds: 280);
const _scrollDuration = Duration(milliseconds: 300);

/// Within this distance (points) of the end, the list counts as at the bottom.
const _bottomSlack = 32.0;

/// One session's side chats, shown by the phone sheet and the desktop panel
/// under a [SideChatCubit].
///
/// A new exchange slides in at the bottom, and the list follows it only when
/// it was already at the bottom, so nothing under the reader's eyes moves. An
/// answer arriving brings its question to the top rather than the answer's
/// end into view.
class const SideChatView({
  super.key,

  /// Drives the chat's list, so that it and the sheet share one drag.
  required final ScrollController scrollController,

  /// The session's harness, named in its refusals.
  required final String harnessName,
  required final VoidCallback onClose,

  /// Whether the question field takes the focus once it shows, for a surface
  /// opened to type into at once, such as the desktop panel.
  required final bool autofocusQuestion,
}) extends StatefulWidget {
  /// Finds the question field in widget and integration tests.
  static const questionFieldKey = ValueKey("sideChat.questionField");

  /// Finds the Send button in widget and integration tests.
  static const sendButtonKey = ValueKey("sideChat.send");

  /// Finds the header's button that lists the earlier chats.
  static const earlierButtonKey = ValueKey("sideChat.earlier");

  /// Finds the header's button that starts a new chat.
  static const newChatButtonKey = ValueKey("sideChat.newChat");

  @override
  State<SideChatView> createState() => _SideChatViewState();
}

class _SideChatViewState() extends State<SideChatView> {
  final _questionController = TextEditingController();

  /// Whether the earlier chats cover the shown one.
  bool _showingEarlier = false;

  /// Counts the chats the reader switched to, so each switch builds the list
  /// afresh while an answer arriving in a new chat keeps it.
  int _threadEpoch = 0;

  /// The first question of the chat the reader reopened, which titles it; null
  /// for a chat started in this sheet.
  String? _reopenedTitle;

  /// Each shown turn's key, by its index, to bring an answered turn into view.
  final Map<int, GlobalKey> _turnKeys = {};

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  /// The thread's scroll position. The thread and the earlier chats take
  /// turns on the sheet's controller, and both hold it while they cross-fade;
  /// the thread attaches last when it comes back.
  ScrollPosition? get _threadPosition => widget.scrollController.positions.lastOrNull;

  bool get _isAtBottom {
    final position = _threadPosition;
    if (position == null) return true;
    return position.pixels >= position.maxScrollExtent - _bottomSlack;
  }

  Duration _motion(Duration duration) => context.isReducedMotion ? Duration.zero : duration;

  void _sayWaitForAnswer() {
    PregoPopupAlertPresenter.of(context).show(
      title: context.loc.sideChatWaitForAnswer,
      variant: PregoPopupAlertsNotificationsVariant.warning,
      duration: PregoPopupAlertPresenter.defaultDuration,
    );
  }

  void _openChat({required SideChat chat}) {
    setState(() {
      _showingEarlier = false;
      _threadEpoch++;
      _turnKeys.clear();
      _reopenedTitle = chat.exchanges.firstOrNull?.question;
    });
    context.read<SideChatCubit>().openChat(id: chat.id);
    _afterFrame(_revealLastTurn);
  }

  void _startNewChat() {
    setState(() {
      _threadEpoch++;
      _turnKeys.clear();
      _reopenedTitle = null;
    });
    context.read<SideChatCubit>().startNewChat();
  }

  void _send() {
    final text = _questionController.text;
    if (text.trim().isEmpty) return;
    _questionController.clear();
    // A question sent over the earlier chats goes to the shown chat, so the
    // thread comes back to show it.
    if (_showingEarlier) setState(() => _showingEarlier = false);
    unawaited(context.read<SideChatCubit>().ask(text: text));
  }

  void _afterFrame(VoidCallback action) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) action();
  });

  void _scrollToBottom() {
    final position = _threadPosition;
    if (position == null) return;
    final target = position.maxScrollExtent;
    final duration = _motion(_scrollDuration);
    if (duration == Duration.zero) {
      position.jumpTo(target);
    } else {
      unawaited(position.animateTo(target, duration: duration, curve: Curves.easeOutCubic));
    }
  }

  /// Puts the newest turn's question at the top, as far as the list scrolls.
  void _revealLastTurn({bool animate = false}) {
    if (_turnKeys.isEmpty) return;
    final last = _turnKeys.keys.reduce(max);
    final turnContext = _turnKeys[last]?.currentContext;
    if (turnContext == null) return;
    Scrollable.ensureVisible(
      turnContext,
      duration: animate ? _motion(_scrollDuration) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  void _onStateChanged({required SideChatState previous, required SideChatState next}) {
    if (next is! SideChatReady) return;
    if (previous is! SideChatReady) {
      // An archived session opens on its newest chat.
      if (next.thread is SideChatExistingThread) _afterFrame(_revealLastTurn);
      return;
    }
    // A refused or failed question goes back into an empty field to edit.
    if (next.ask case SideQuestionRefused(:final question) || SideQuestionFailed(:final question)
        when previous.ask is SideQuestionWaiting && _questionController.text.isEmpty) {
      _questionController.text = question;
    }
    final answered = _exchangeCount(next) > _exchangeCount(previous);
    final askChanged = previous.ask.runtimeType != next.ask.runtimeType;
    if (!(answered || askChanged) || !_isAtBottom) return;
    _afterFrame(answered ? () => _revealLastTurn(animate: true) : _scrollToBottom);
  }

  static int _exchangeCount(SideChatReady state) => switch (state.thread) {
    SideChatNewThread() => 0,
    SideChatExistingThread(:final chat) => chat.exchanges.length,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<SideChatCubit>();
    final state = cubit.state;
    final loc = context.loc;
    return BlocListener<SideChatCubit, SideChatState>(
      listenWhen: (previous, next) {
        _onStateChanged(previous: previous, next: next);
        return false;
      },
      listener: (_, _) {},
      child: Column(
        children: [
          _buildHeader(state: state, canAsk: cubit.canAsk),
          Expanded(
            child: AnimatedSwitcher(
              duration: _motion(_fadeDuration),
              child: switch (state) {
                SideChatLoading() => const Center(
                  key: ValueKey("loading"),
                  child: PregoActivityIndicator(color: null),
                ),
                SideChatLoadFailed() => _SideChatLoadFailed(
                  key: const ValueKey("failed"),
                  onRetry: () => unawaited(cubit.reload()),
                ),
                final SideChatReady ready => Stack(
                  key: const ValueKey("ready"),
                  children: [
                    Positioned.fill(
                      child: _buildThread(ready: ready, canAsk: cubit.canAsk),
                    ),
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: _motion(_fadeDuration),
                        child: _showingEarlier && ready.earlierChats.isNotEmpty
                            ? _EarlierChats(
                                scrollController: widget.scrollController,
                                chats: ready.earlierChats,
                                onOpen: (chat) => _openChat(chat: chat),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
          if (state is SideChatReady)
            cubit.canAsk
                ? _SideChatInput(
                    controller: _questionController,
                    autofocus: widget.autofocusQuestion,
                    waiting: state.ask is SideQuestionWaiting,
                    onSend: _send,
                    onSendWhileWaiting: _sayWaitForAnswer,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PregoSpacing.xl,
                      PregoSpacing.md,
                      PregoSpacing.xl,
                      PregoSpacing.lg,
                    ),
                    child: Text(
                      loc.sideChatArchived,
                      textAlign: TextAlign.center,
                      style: context.prego.textTheme.textSm.regular.copyWith(
                        color: context.prego.colors.textTertiary,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildHeader({required SideChatState state, required bool canAsk}) {
    final loc = context.loc;
    final ready = state is SideChatReady ? state : null;
    final waiting = ready?.ask is SideQuestionWaiting;
    final showingEarlier = _showingEarlier && ready != null && ready.earlierChats.isNotEmpty;
    final title = switch (ready?.thread) {
      _ when showingEarlier => loc.sideChatEarlier,
      // Read-only chats are all reopened ones.
      SideChatExistingThread(:final chat) when !canAsk => chat.exchanges.firstOrNull?.question ?? loc.sideChatTitle,
      SideChatExistingThread() => _reopenedTitle ?? loc.sideChatTitle,
      SideChatNewThread() || null => loc.sideChatTitle,
    };
    return PregoTopNavigationSheets(
      title: title,
      alignment: PregoSheetTitleAlignment.start,
      showGrabber: false,
      onBack: showingEarlier ? () => setState(() => _showingEarlier = false) : null,
      onClose: widget.onClose,
      // One action holding both buttons: the header spaces its actions at
      // once, so a button coming or going there would shift its neighbour in
      // a single frame. Here each one eases its own slot open and shut.
      actions: ready == null || showingEarlier
          ? null
          : [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderSlot(
                    visible: ready.earlierChats.isNotEmpty,
                    gap: 0,
                    child: _HeaderButton(
                      key: SideChatView.earlierButtonKey,
                      icon: TablerRegular.history,
                      label: loc.sideChatEarlier,
                      count: ready.earlierChats.length,
                      waiting: waiting,
                      onPressed: () => setState(() => _showingEarlier = true),
                      onPressedWhileWaiting: _sayWaitForAnswer,
                    ),
                  ),
                  _HeaderSlot(
                    visible: canAsk && ready.thread is SideChatExistingThread,
                    gap: PregoSpacing.md,
                    child: _HeaderButton(
                      key: SideChatView.newChatButtonKey,
                      icon: TablerRegular.message_plus,
                      label: loc.sideChatNew,
                      count: null,
                      waiting: waiting,
                      onPressed: _startNewChat,
                      onPressedWhileWaiting: _sayWaitForAnswer,
                    ),
                  ),
                ],
              ),
            ],
    );
  }

  Widget _buildThread({required SideChatReady ready, required bool canAsk}) {
    final exchanges = switch (ready.thread) {
      SideChatNewThread() => const <SideChatExchange>[],
      SideChatExistingThread(:final chat) => chat.exchanges,
    };
    GlobalKey turnKey(int index) => _turnKeys.putIfAbsent(index, GlobalKey.new);
    final pending = ready.ask;
    // Not a lazy list: every turn stays built, so the newest one can be
    // brought into view however long the chat is. A sliver viewport, like the
    // chat's, so the overscroll stretch holds when the thread lays out again
    // mid-scroll, as a button does when it slides under a resting trackpad
    // cursor. A SingleChildScrollView snaps its overscroll back to the edge on
    // every layout.
    return CustomScrollView(
      key: ValueKey(_threadEpoch),
      // The earlier chats take the sheet's drags while they cover the thread.
      controller: _showingEarlier ? null : widget.scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(PregoSpacing.xl, PregoSpacing.xs, PregoSpacing.xl, PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canAsk) const _Footnote(),
                for (final (index, exchange) in exchanges.indexed)
                  _SideChatTurn(
                    key: turnKey(index),
                    question: exchange.question,
                    animateIn: false,
                    reply: _Answer(key: ValueKey(exchange.id), exchange: exchange),
                  ),
                if (pending
                    case SideQuestionWaiting(:final question) ||
                        SideQuestionRefused(:final question) ||
                        SideQuestionFailed(:final question))
                  _SideChatTurn(
                    key: turnKey(exchanges.length),
                    question: question,
                    animateIn: true,
                    reply: switch (pending) {
                      SideQuestionRefused(:final reason) => _Unanswered(
                        key: ValueKey(reason),
                        message: _refusalMessage(reason: reason),
                        onRetry: switch (reason) {
                          SideQuestionRefusal.harnessUnsupported || SideQuestionRefusal.tooLong => null,
                          _ => _retry,
                        },
                      ),
                      SideQuestionFailed() => _Unanswered(
                        key: const ValueKey("failed"),
                        message: context.loc.sideChatAskFailed,
                        onRetry: _retry,
                      ),
                      SideQuestionWaiting() || SideQuestionIdle() => const _Thinking(key: ValueKey("thinking")),
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _retry() {
    final cubit = context.read<SideChatCubit>();
    // The question is asked again from Retry, so it leaves the field, but a
    // different draft typed meanwhile stays.
    if (cubit.state
        case SideChatReady(
          ask: SideQuestionRefused(:final question) || SideQuestionFailed(:final question),
        )
        when _questionController.text == question) {
      _questionController.clear();
    }
    unawaited(cubit.retry());
  }

  String _refusalMessage({required SideQuestionRefusal reason}) {
    final loc = context.loc;
    return switch (reason) {
      SideQuestionRefusal.harnessUnsupported => loc.sideQuestionHarnessUnsupported(widget.harnessName),
      SideQuestionRefusal.harnessUpdateRequired => loc.sideChatRefusedHarnessUpdateRequired(widget.harnessName),
      SideQuestionRefusal.noTurnYet => loc.sideChatRefusedNoTurnYet,
      SideQuestionRefusal.tooLong => loc.sideChatRefusedTooLong,
      SideQuestionRefusal.noAnswer => loc.sideChatRefusedNoAnswer,
      SideQuestionRefusal.repeatedRunningReply => loc.sideChatRefusedRepeatedRunningReply(widget.harnessName),
      SideQuestionRefusal.unknown => loc.sideChatRefusedUnknown,
    };
  }
}

/// A header button's slot, with [gap] before the button. While [visible]
/// changes, as the chat loads or an answer lands, the slot eases open or shut
/// so the button beside it slides over, and the button fades and grows in its
/// place, or shrinks and fades out. Reduced motion applies each change at once.
class const _HeaderSlot({required final bool visible, required final double gap, required final Widget child})
    extends StatelessWidget {
  static const _hiddenScale = 0.9;

  /// The button starts to show once its neighbour has mostly slid off its
  /// place, so the two hardly overlap while it fades.
  static const _fadeInterval = Interval(0.4, 1);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: context.isReducedMotion ? Duration.zero : _fadeDuration,
      curve: Curves.easeOut,
      // A leaving button takes no more taps.
      child: IgnorePointer(ignoring: !visible, child: child),
      builder: (context, shown, child) {
        if (shown == 0 && !visible) return const SizedBox.shrink();
        return Align(
          // The button stays put at the slot's end while the slot opens.
          alignment: AlignmentDirectional.centerEnd,
          widthFactor: shown,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: gap),
            child: Opacity(
              opacity: _fadeInterval.transform(shown),
              child: Transform.scale(scale: _hiddenScale + (1 - _hiddenScale) * shown, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// A glass header button that looks disabled while a question waits, and then
/// says why instead of acting.
class const _HeaderButton({
  super.key,
  required final IconData icon,
  required final String label,
  required final int? count,
  required final bool waiting,
  required final VoidCallback onPressed,
  required final VoidCallback onPressedWhileWaiting,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = this.count;
    return PregoButtonsIconGlass(
      icon: icon,
      size: PregoButtonsIconGlassSize.md,
      semanticLabel: count == null ? label : "$label, $count",
      iconColor: waiting ? context.prego.colors.textDisabled : null,
      trailing: count == null
          ? null
          : Text(
              "$count",
              style: context.prego.textTheme.textSm.medium.copyWith(
                color: waiting ? context.prego.colors.textDisabled : context.prego.colors.textPrimary,
              ),
            ),
      onPressed: waiting ? onPressedWhileWaiting : onPressed,
    );
  }
}

class const _Footnote() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsets.only(bottom: PregoSpacing.lg),
      child: Text(
        context.loc.sideChatFootnote,
        style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
      ),
    );
  }
}

/// A question and what came of it. [animateIn] slides a newly asked turn in
/// once; the same turn keeps its place when its answer arrives.
class const _SideChatTurn({
  super.key,
  required final String question,
  required final Widget reply,
  required final bool animateIn,
}) extends StatefulWidget {
  @override
  State<_SideChatTurn> createState() => _SideChatTurnState();
}

class _SideChatTurnState() extends State<_SideChatTurn> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(vsync: this, duration: _slideInDuration, value: 1);
  late final CurvedAnimation _curved = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);

  bool _entranceDecided = false;

  /// Here rather than in initState, which can't read the motion preference.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceDecided) return;
    _entranceDecided = true;
    if (widget.animateIn && !context.isReducedMotion) _entrance.forward(from: 0);
  }

  @override
  void dispose() {
    _curved.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_curved),
        child: Padding(
          padding: const EdgeInsets.only(bottom: PregoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FractionallySizedBox(
                  widthFactor: 0.85,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: prego.colors.bgSurface2,
                        borderRadius: BorderRadius.circular(PregoRadius.xl),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          widget.question,
                          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PregoSpacing.sm),
              AnimatedSwitcher(
                duration: context.isReducedMotion ? Duration.zero : _fadeDuration,
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.topStart,
                  children: [...previous, ?current],
                ),
                child: widget.reply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quiet row shown while the answer is made, with the transcript's glyph.
class const _Thinking({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return TranscriptStepRow(
      leading: PregoAiLoader(animate: true, fillMode: .outline, color: prego.colors.textSecondary),
      label: context.loc.sessionDetailThinking,
      detail: null,
      live: true,
      color: null,
      trailing: null,
    );
  }
}

/// Why a question got no answer, where its answer would be, with Retry when
/// asking again could help.
class const _Unanswered({
  super.key,
  required final String message,
  required final VoidCallback? onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final onRetry = this.onRetry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PregoSpacing.sm,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: PregoSpacing.sm,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(TablerRegular.alert_circle, size: PregoIconSize.md, color: prego.colors.fgWarningPrimary),
            ),
            Expanded(
              child: Text(
                message,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ),
          ],
        ),
        if (onRetry != null)
          PregoButtonsSolid(
            label: context.loc.sideChatRetry,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            leadingIcon: TablerRegular.refresh,
            onPressed: onRetry,
          ),
      ],
    );
  }
}

/// An answer, in the transcript's Markdown, with its notice and actions.
class const _Answer({super.key, required final SideChatExchange exchange}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final notice = exchange.answerNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextPartWidget(text: exchange.answer),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: PregoSpacing.xs),
            child: Text(notice, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary)),
          ),
        // The answer's actions. Sending an answer to the main session will
        // join Copy here.
        Row(
          children: [
            PregoCopyIconButton(
              tooltip: context.loc.sideChatCopyAnswer,
              onCopy: () => copyTextToClipboard(text: exchange.answer, operation: "side question answer"),
            ),
          ],
        ),
      ],
    );
  }
}

/// The session's other side chats, newest first, titled by their first
/// question; it covers the shown chat and fades with it.
class const _EarlierChats({
  required final ScrollController scrollController,
  required final List<SideChat> chats,
  required final ValueChanged<SideChat> onOpen,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return ColoredBox(
      color: prego.colors.bgSecondary,
      child: ListView(
        // The sheet's, so the list grows and closes the sheet like the thread.
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xs),
        children: [
          for (final chat in chats)
            PregoTappable(
              key: ValueKey(chat.id),
              onTap: () => onOpen(chat),
              borderRadius: BorderRadius.circular(PregoRadius.lg),
              containerBuilder: (child) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.md),
                child: child,
              ),
              child: Row(
                spacing: PregoSpacing.md,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          chat.exchanges.firstOrNull?.question ?? context.loc.sideChatTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
                        ),
                        Text(
                          context.loc.sideChatQuestionCount(chat.exchanges.length),
                          style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Icon(TablerRegular.chevron_right, size: PregoIconSize.md, color: prego.colors.textTertiary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class const _SideChatLoadFailed({super.key, required final VoidCallback onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.md,
        children: [
          Text(
            context.loc.sideChatLoadFailed,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
          PregoButtonsSolid(
            label: context.loc.sideChatRetry,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// A single line that grows to a few, and Send. While a question waits Send
/// looks disabled and says why when tapped.
class const _SideChatInput({
  required final TextEditingController controller,
  required final bool autofocus,
  required final bool waiting,
  required final VoidCallback onSend,
  required final VoidCallback onSendWhileWaiting,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PregoSpacing.xl, PregoSpacing.sm, PregoSpacing.xl, PregoSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: prego.colors.bgSurface1,
          borderRadius: BorderRadius.circular(PregoRadius.xl),
          border: Border.all(color: prego.colors.borderPrimary),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.lg, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: PregoSpacing.sm,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    key: SideChatView.questionFieldKey,
                    controller: controller,
                    autofocus: autofocus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => waiting ? onSendWhileWaiting() : onSend(),
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                    decoration: InputDecoration.collapsed(
                      hintText: loc.sideQuestionAsk,
                      hintStyle: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textTertiary),
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final hasText = controller.text.trim().isNotEmpty;
                  // A disabled button lets the tap through to say why.
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: waiting ? onSendWhileWaiting : null,
                    child: PregoButtonsSolid.iconOnly(
                      key: SideChatView.sendButtonKey,
                      leadingIcon: TablerRegular.arrow_up,
                      semanticLabel: loc.sessionDetailSend,
                      hierarchy: PregoButtonsSolidHierarchy.primary,
                      size: PregoButtonsSolidSize.sm,
                      onPressed: hasText && !waiting ? onSend : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
