import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";

/// Lets a sent dictation's words find the bubble they turn into. It sits above
/// both the composer and the message list, which know nothing of each other; the
/// composer can't name the bubble either, as the cubit generates the prompt's id.
class const SentBubbleLanding({super.key, required final Widget child}) extends StatefulWidget {
  static SentBubbleLandingController of({required BuildContext context}) {
    final scope = context.getInheritedWidgetOfExactType<_LandingScope>();
    return (scope ?? (throw StateError("SentBubbleLanding was not found in the widget tree"))).controller;
  }

  @override
  State<SentBubbleLanding> createState() => _SentBubbleLandingState();
}

class _SentBubbleLandingState() extends State<SentBubbleLanding> {
  final _controller = SentBubbleLandingController();

  @override
  Widget build(BuildContext context) => _LandingScope(controller: _controller, child: widget.child);
}

class const _LandingScope({required final SentBubbleLandingController controller, required super.child})
    extends InheritedWidget {
  @override
  bool updateShouldNotify(_LandingScope oldWidget) => false;
}

sealed class const _Phase();

final class const _Idle() extends _Phase;

/// A send has gone out, and the next new bubble is its.
final class const _Expecting() extends _Phase;

/// The bubble has been built and stays hidden until the words reach it.
final class const _Held({required final RenderLandingSlot slot, required final String text}) extends _Phase;

/// That bubble has left the tree. A row swapping its queued bubble for the
/// message's own, when the echo comes back mid-glide, builds the next in this frame.
final class const _Lost({required final String text}) extends _Phase;

final class SentBubbleLandingController() {
  _Phase _phase = const _Idle();

  /// The composer is about to send words that are on screen.
  void expect() => _phase = const _Expecting();

  bool get isExpecting => _phase is _Expecting;

  /// What the bubble waiting for the words shows, once there is one.
  String? get heldText => switch (_phase) {
    _Held(:final text) => text,
    _Idle() || _Expecting() || _Lost() => null,
  };

  /// Where that bubble's row comes to rest, in [ancestor]'s coordinates. Its
  /// place in the list can still be changing, so this is read afresh on every
  /// frame of the glide.
  Rect? heldRect({required RenderObject ancestor}) => switch (_phase) {
    _Held(:final slot) => slot.restingRectIn(ancestor: ancestor),
    _Idle() || _Expecting() || _Lost() => null,
  };

  /// The words have arrived, or won't: the bubble shows and nothing is expected.
  void handOver() {
    if (_phase case _Held(:final slot)) slot.hidden = false;
    _phase = const _Idle();
  }

  void _claim({required RenderLandingSlot slot, required String text, required bool arriving}) {
    final bool takes = switch (_phase) {
      _Expecting() => arriving,
      _Lost(text: final lost) => lost == text,
      _Idle() || _Held() => false,
    };
    if (!takes) return;
    slot.hidden = true;
    _phase = _Held(slot: slot, text: text);
  }

  void _release({required RenderLandingSlot slot}) {
    if (_phase case _Held(slot: final held, :final text) when identical(held, slot)) _phase = _Lost(text: text);
  }
}

/// Wraps a user bubble's surface, so that the words can land on it. It has to be
/// built while a send is expected to take any part in that.
class const SentBubbleSlot({super.key, required final String? text, required super.child})
    extends SingleChildRenderObjectWidget {
  @override
  RenderLandingSlot createRenderObject(BuildContext context) {
    final text = this.text;
    if (text == null) return RenderLandingSlot(onAttach: (_) {}, onDetach: (_) {});
    final landing = SentBubbleLanding.of(context: context);
    final arriving = SentBubbleArrival._isArriving(context: context);
    return RenderLandingSlot(
      onAttach: (slot) => landing._claim(slot: slot, text: text, arriving: arriving),
      onDetach: (slot) => landing._release(slot: slot),
    );
  }
}

/// Tells the bubbles under it whether they can be the one being sent. A list says
/// so per row, as scrolling back down after a send also builds rows, and bubbles
/// outside this, as the list's pinned copies are, never can.
class const SentBubbleArrival({super.key, required final bool arriving, required super.child}) extends InheritedWidget {
  static bool _isArriving({required BuildContext context}) =>
      context.getInheritedWidgetOfExactType<SentBubbleArrival>()?.arriving ?? false;

  @override
  bool updateShouldNotify(SentBubbleArrival oldWidget) => false;
}

/// A place words can land on: it hides what it wraps while they are on their way
/// and says where it is. Hiding only skips the paint, so that nothing rebuilds or
/// moves when the words arrive.
class RenderLandingSlot({
  required final void Function(RenderLandingSlot slot) onAttach,
  required final void Function(RenderLandingSlot slot) onDetach,
}) extends RenderProxyBox {
  bool _hidden = false;
  bool get hidden => _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
  }

  Rect? rectIn({required RenderObject ancestor}) =>
      hasSize ? MatrixUtils.transformRect(getTransformTo(ancestor), Offset.zero & size) : null;

  /// Where this ends up once its reversed list is back at its latest edge, as a
  /// send always takes it. Words aimed at where the row is now would dive towards
  /// the composer and come back up with it.
  Rect? restingRectIn({required RenderObject ancestor}) {
    final rect = rectIn(ancestor: ancestor);
    if (rect == null) return null;
    // The offset of the layout that placed the row, which the position is ahead
    // of while a glide's frame has yet to lay out.
    final toEdge = switch (RenderAbstractViewport.maybeOf(this)) {
      RenderViewportBase(:final firstChild?) => firstChild.constraints.scrollOffset,
      _ => 0.0,
    };
    return rect.translate(0, -toEdge);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    onAttach(this);
  }

  @override
  void detach() {
    onDetach(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }
}
