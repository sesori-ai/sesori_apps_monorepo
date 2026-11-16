import "dart:math" as math;

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/widgets/desktop_connection_pill_slot.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

/// Makes the cubit of one opening of a session's side-chat panel.
typedef DesktopSideChatCubitFactory = SideChatCubit Function({
  required String sessionId,
  required String pluginId,
  required SideQuestionAvailability availability,
  required bool isArchived,
  required String? initialQuestion,
});

/// Builds the session page around its side chats: [openSideChat] shows them,
/// and [panel] goes last in the page's full-size [Stack], so it floats over the
/// page under the session page's own scopes.
typedef DesktopSideChatPageBuilder = Widget Function(
  BuildContext context, {
  required SideChatOpener openSideChat,
  required Widget panel,
});

/// A session page's side chats, in a panel that floats over the page's trailing
/// edge, from under the toolbar to just above the composer, so the composer's
/// Send and Stop stay in reach. With no composer it runs to the page's bottom.
///
/// The panel slides in from the window's edge by transform, like the sidebar,
/// so the transcript neither moves nor reflows, and the page around it keeps
/// taking clicks and scrolls. Escape (with the focus anywhere in the page) and
/// the panel's close button close it. The panel belongs to its session's page,
/// so switching sessions closes it.
class const DesktopSideChatPanelHost({
  super.key,
  required final DesktopSideChatCubitFactory createCubit,
  required final DesktopSideChatPageBuilder builder,
}) extends StatefulWidget {
  /// The panel's width.
  static const double width = 380;

  /// Finds the open panel in widget tests.
  static const panelKey = Key("desktop-side-chat-panel");

  @override
  State<DesktopSideChatPanelHost> createState() => _DesktopSideChatPanelHostState();
}

/// The gap the panel keeps from the window's trailing and bottom edges, and
/// from the top of the controls docked at the page's bottom. The composer keeps
/// 8 pt of clear room above its surface, so the panel's edge stands 20 pt clear
/// of the composer itself.
const double _inset = PregoSpacing.lg;

/// The shortest the panel gets to stay above the composer. Where a short
/// window, a tall draft or docked cards leave less room, it keeps this height
/// and runs over the composer's top, never past the page's bottom inset; the
/// composer's Send row, at its bottom, stays clear unless the window is shorter
/// still.
const double _minHeightAboveComposer = 300;

/// How far the panel travels to clear the window's edge, its shadow included.
const double _travel = DesktopSideChatPanelHost.width + _inset + 48;

// The sidebar's timing and curve, so the two panels move alike.
const _openDuration = Duration(milliseconds: 200);
const _closeDuration = Duration(milliseconds: 180);
const _curve = Cubic(0.25, 0.55, 0.2, 1);

/// One opening of the panel. Its cubit lives until the panel has slid away.
typedef _Opening = ({Key key, String pluginId, SideChatCubit Function() createCubit});

class _DesktopSideChatPanelHostState() extends State<DesktopSideChatPanelHost> with SingleTickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(vsync: this)..addStatusListener(_onSlideStatus);
  late final Animation<double> _shown = CurvedAnimation(parent: _slide, curve: _curve)..addListener(_coverPage);
  late final DesktopTrailingPanelCover _cover;

  /// Whether the page is on top, and so the one the pill keeps clear of.
  bool _isCurrentPage = true;
  final _scrollController = ScrollController();
  final _focusScope = FocusScopeNode(debugLabel: "Side chat panel");

  /// How far the page's composer rises over its bottom; 0 with no composer.
  final _composerExtent = ValueNotifier<double>(0);

  /// Null while the panel is closed.
  _Opening? _opening;
  int _openings = 0;

  /// Where the focus was when the panel opened, to hand it back on close.
  FocusNode? _focusBeforeOpening;

  @override
  void initState() {
    super.initState();
    // Held, as the page sets it back to 0 while it is torn down.
    _cover = context.read();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A pushed subtask or Changes page takes the pill over, and this page
    // takes it back on return.
    _isCurrentPage = ModalRoute.isCurrentOf(context) ?? true;
    _coverPage();
  }

  @override
  void dispose() {
    _cover.release(by: this);
    _slide.dispose();
    _scrollController.dispose();
    _focusScope.dispose();
    _composerExtent.dispose();
    super.dispose();
  }

  void _open({
    required BuildContext context,
    required String sessionId,
    required String pluginId,
    required SideQuestionAvailability availability,
    required bool isArchived,
    required String? initialQuestion,
  }) {
    // Opened again while it shows or slides away, the panel keeps its chat,
    // unless a question from the composer asks for a new one.
    if (_opening == null || initialQuestion != null) {
      _focusBeforeOpening = FocusManager.instance.primaryFocus;
      setState(
        () => _opening = (
          key: ValueKey(_openings++),
          pluginId: pluginId,
          createCubit: () => widget.createCubit(
            sessionId: sessionId,
            pluginId: pluginId,
            availability: availability,
            isArchived: isArchived,
            initialQuestion: initialQuestion,
          ),
        ),
      );
    }
    // The panel takes the focus, so Escape reaches it and its question field
    // takes the typing once it shows.
    _focusScope.requestFocus();
    _slideTo(shown: true);
  }

  void _close() {
    if (_opening == null) return;
    if (_focusScope.hasFocus) {
      switch (_focusBeforeOpening) {
        case final previous? when previous.context != null && previous.canRequestFocus:
          previous.requestFocus();
        case _:
          _focusScope.unfocus();
      }
    }
    _slideTo(shown: false);
  }

  void _slideTo({required bool shown}) {
    // A keyboard shortcut is answered at once, as the sidebar's are.
    if (prefersReducedMotion(context) || pregoActivatedByKeyboard) {
      _slide.value = shown ? 1 : 0;
    } else if (shown) {
      _slide.animateTo(1, duration: _openDuration);
    } else {
      _slide.animateBack(0, duration: _closeDuration);
    }
  }

  /// Tells the shell how much of the page's edge the panel covers, so the
  /// connection pill moves aside with it.
  void _coverPage() {
    if (_isCurrentPage) {
      _cover.cover(by: this, width: DesktopSideChatPanelHost.width + _inset, shown: _shown.value);
    } else {
      _cover.release(by: this);
    }
  }

  void _onSlideStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) setState(() => _opening = null);
  }

  void _onComposerExtent(double extent) {
    // A report can land after the page has gone.
    if (mounted) _composerExtent.value = extent;
  }

  @override
  Widget build(BuildContext context) {
    final opening = _opening;
    return CallbackShortcuts(
      bindings: {if (opening != null) const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: SessionComposerExtentScope(
        onExtentChanged: _onComposerExtent,
        child: widget.builder(
          context,
          openSideChat: _open,
          panel: PositionedDirectional(
            top: DesktopPageToolbar.height,
            bottom: _inset,
            end: _inset,
            width: DesktopSideChatPanelHost.width,
            // Only the bottom edge follows the composer as it grows and folds;
            // the slide moves the panel sideways alone.
            child: ValueListenableBuilder(
              valueListenable: _composerExtent,
              builder: (context, composerExtent, child) => LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: AlignmentDirectional.topCenter,
                  child: SizedBox(
                    height: math.min(
                      constraints.maxHeight,
                      math.max(_minHeightAboveComposer, constraints.maxHeight - composerExtent),
                    ),
                    child: child,
                  ),
                ),
              ),
              child: switch (opening) {
                null => const SizedBox.shrink(),
                final shown => _SlidingPanel(
                  shown: _shown,
                  child: FocusScope(
                    node: _focusScope,
                    child: BlocProvider(
                      key: shown.key,
                      create: (_) => shown.createCubit(),
                      child: SideChatView(
                        scrollController: _scrollController,
                        harnessName: PregoBrandLogo.displayNameFor(shown.pluginId),
                        onClose: _close,
                        autofocusQuestion: true,
                      ),
                    ),
                  ),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel's surface, moved toward the window's trailing edge by how much
/// of it [shown] leaves hidden.
class const _SlidingPanel({required final Animation<double> shown, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    const radius = BorderRadius.all(Radius.circular(PregoRadius.x2l));
    final towardEnd = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final surface = RepaintBoundary(
      child: DecoratedBox(
        key: DesktopSideChatPanelHost.panelKey,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: prego.colors.brightness == .dark ? prego.shadows.xl + _liftDark : _liftLight,
        ),
        child: Material(
          color: prego.colors.pointerPanelFill,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: prego.colors.borderPrimary),
          ),
          child: child,
        ),
      ),
    );
    return AnimatedBuilder(
      animation: shown,
      builder: (context, child) {
        // A leaving panel takes no clicks and is no longer announced; its
        // focus has already gone back to the page.
        final leaving = shown.status == AnimationStatus.reverse;
        return Transform.translate(
          offset: Offset(towardEnd * _travel * (1 - shown.value), 0),
          child: IgnorePointer(
            ignoring: leaving,
            child: ExcludeSemantics(excluding: leaving, child: child),
          ),
        );
      },
      child: surface,
    );
  }
}

// The lift of a pointer shell's popovers, so the panel reads as one of them.
const List<BoxShadow> _liftDark = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 12), blurRadius: 32)];
const List<BoxShadow> _liftLight = [BoxShadow(color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 24)];
