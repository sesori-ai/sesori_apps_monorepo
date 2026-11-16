import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../session_detail/session_detail_presentation_scope.dart";
import "side_chat_view.dart";

/// Shows a session's side chats in a two-height sheet over its page, which
/// stays mounted underneath and keeps streaming. [createCubit] makes the
/// sheet's cubit, which lives as long as the sheet.
///
/// [context] is under the session page's [SessionDetailPresentationScope],
/// and [SessionDetailCubit], which the answers' links use.
void showSideChatSheet({
  required BuildContext context,
  required String pluginId,
  required SideChatCubit Function() createCubit,
}) {
  final scope = SessionDetailPresentationScope.read(context);
  // The answers' file links read the session cubit, which the sheet's route
  // does not inherit.
  final sessionCubit = context.read<SessionDetailCubit>();
  // ignore: no_slop_linter/avoid_navigator_of, the sheet is a transient route over the session page
  final navigator = Navigator.of(context);
  final closed = showPregoDetentSheet<void>(
    context: context,
    builder: (context, scrollController) => scope.around(
      openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {
        navigator.pop();
        scope.openSession(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly);
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sessionCubit),
          BlocProvider(create: (_) => createCubit()),
        ],
        child: SideChatView(
          scrollController: scrollController,
          harnessName: PregoBrandLogo.displayNameFor(pluginId),
          onClose: navigator.pop,
          // The keyboard waits for a tap, so the sheet opens on what it holds.
          autofocusQuestion: false,
        ),
      ),
    ),
  );
  SideChatKeyboardHold.holdUntil(context: context, closed: closed);
}

/// Keeps the session page laid out against the keyboard it had when a side
/// chat opened, until the sheet closes. A side chat sent from the composer
/// takes the composer's focus, so the keyboard slides down under the sheet;
/// without the hold the transcript behind it would slide down with it.
///
/// On close the composer takes its focus back and the keyboard rises again, so
/// the page keeps the held keyboard while it does, then eases to the live one:
/// with no keyboard coming back, the page settles down to the bottom.
class const SideChatKeyboardHold({super.key, required final Widget child}) extends StatefulWidget {
  /// Holds the nearest [SideChatKeyboardHold] above [context] until [closed]
  /// completes. Without one, the page follows the keyboard as usual.
  static void holdUntil({required BuildContext context, required Future<void> closed}) =>
      context.findAncestorStateOfType<_SideChatKeyboardHoldState>()?._holdUntil(closed: closed);

  @override
  State<SideChatKeyboardHold> createState() => _SideChatKeyboardHoldState();
}

class _SideChatKeyboardHoldState() extends State<SideChatKeyboardHold> with SingleTickerProviderStateMixin {
  /// 1 while held, easing to 0 once the sheet closes.
  late final AnimationController _hold = AnimationController(vsync: this, duration: _releaseDuration);
  double _held = 0;

  /// The first 480 ms outlast a returning keyboard's rise (about 450 ms on
  /// iOS), so the page never drops below it; the rest eases a keyboard that
  /// stays down out of the layout.
  static const _releaseDuration = Duration(milliseconds: 800);
  static const _releaseCurve = Interval(0.6, 1, curve: Curves.easeInOut);

  void _holdUntil({required Future<void> closed}) {
    _held = MediaQuery.viewInsetsOf(context).bottom;
    _hold.value = 1;
    unawaited(
      closed.whenComplete(() {
        if (mounted) _hold.animateBack(0, curve: _releaseCurve);
      }),
    );
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _hold,
    child: widget.child,
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      final keyboard = math.max(mediaQuery.viewInsets.bottom, _held * _hold.value);
      return MediaQuery(
        // The held keyboard still covers the home indicator, so its safe area
        // stays out of the padding, as the platform reports it.
        data: mediaQuery.copyWith(
          viewInsets: mediaQuery.viewInsets.copyWith(bottom: keyboard),
          padding: mediaQuery.padding.copyWith(bottom: math.max(0, mediaQuery.viewPadding.bottom - keyboard)),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
