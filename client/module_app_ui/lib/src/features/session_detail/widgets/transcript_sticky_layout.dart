import "dart:math";

import "package:flutter/foundation.dart";

/// Where a prompt turn's opener bubble is, in the transcript's box.
sealed class const TranscriptStickyPlace();

/// The opener's row is not built and lies above the built rows.
final class const TranscriptStickyAbove() extends TranscriptStickyPlace;

/// The opener's bubble is built and spans [top] to [bottom].
final class const TranscriptStickyBuilt({required final double top, required final double bottom})
    extends TranscriptStickyPlace;

/// The opener's row is not built and lies below the built rows.
final class const TranscriptStickyBelow() extends TranscriptStickyPlace;

typedef TranscriptStickyOpener = ({String id, TranscriptStickyPlace place});

/// Which part of its bubble a pin shows.
@immutable
sealed class const TranscriptPinView();

/// The bubble's start, cut where the pin ends: a message the reader saw whole
/// before it pinned.
final class const TranscriptPinStart() extends TranscriptPinView;

/// The bubble's end, cut where the pin starts: a message taller than the rows
/// below the pin line, which pins only once the reader has scrolled to its
/// end. [fade], from 0 to 1, is how far the cut top edge has faded in since.
final class const TranscriptPinEnd({required final double fade}) extends TranscriptPinView {
  @override
  bool operator ==(Object other) => other is TranscriptPinEnd && other.fade == fade;

  @override
  int get hashCode => fade.hashCode;
}

/// A message painted over the transcript: its bubble spans [top] to
/// `top + height` of a bubble [fullHeight] tall, showing [view], with a halo
/// of [elevation].
typedef TranscriptPinnedPrompt = ({
  String openerId,
  double top,
  double height,
  double fullHeight,
  double elevation,
  TranscriptPinView view,
});

/// What the pinned prompts paint, back to front, and the openers whose own
/// bubbles they stand in for, which must not paint.
@immutable
final class const TranscriptStickyLayout({
  required final List<TranscriptPinnedPrompt> pinned,
  required final Set<String> hiddenOpenerIds,
}) {
  static const empty = TranscriptStickyLayout(pinned: [], hiddenOpenerIds: {});

  @override
  bool operator ==(Object other) =>
      other is TranscriptStickyLayout &&
      listEquals(other.pinned, pinned) &&
      setEquals(other.hiddenOpenerIds, hiddenOpenerIds);

  @override
  int get hashCode => Object.hash(Object.hashAll(pinned), Object.hashAllUnordered(hiddenOpenerIds));
}

/// Space kept between a pinned prompt and the next opener pushing it out.
const double transcriptStickyGap = 8;

/// How far the halo reaches beyond the bubble: its blur plus its spread.
const double transcriptStickyHaloReach = 42;

/// The index in [openers] of the prompt being read: the last one at or above
/// the pin line at [pinTop]; -1 before any is.
int currentTranscriptStickyIndex({required List<TranscriptStickyOpener> openers, required double pinTop}) =>
    openers.lastIndexWhere(
      (opener) => switch (opener.place) {
        TranscriptStickyAbove() => true,
        TranscriptStickyBuilt(:final top) => top <= pinTop,
        TranscriptStickyBelow() => false,
      },
    );

/// Pins the message being read at [pinTop], as a header that compacts with
/// the scroll. Every position follows from the messages' current bubbles
/// alone, so the pin tracks the rows in the frame they move and a reversed
/// scroll retraces it exactly.
///
/// The current message is the last one at or above the pin line. While its
/// bubble reaches below the compact height, the pin's top holds at the line
/// and its bottom rides the bubble's; from there it keeps the compact height,
/// [compactHeight] or the whole bubble when that is shorter. Where it takes
/// over, the pin covers its bubble exactly, which then stops painting. The
/// next message pushes it up and out, [transcriptStickyGap] above itself, and
/// then pins the same way. The halo shows only while rows slide under the
/// compact pin, and drains as the next message arrives or the bubble returns.
///
/// A bubble taller than the rows between the pin line and [viewportBottom]
/// could never be read to its end that way, so it scrolls on as a row and
/// pins its end only once just the compact height of it is left below the
/// line. That pin covers the bubble's end exactly, and the bubble keeps
/// painting, its rest scrolling away above the line.
///
/// [openers] are in transcript order; [fullHeights] holds the height of each
/// pinnable message's copy, its whole bubble unless the bubble is a pasted
/// document. Nothing pins until the current message can.
TranscriptStickyLayout layOutTranscriptStickyPrompts({
  required List<TranscriptStickyOpener> openers,
  required Map<String, double> fullHeights,
  required double compactHeight,
  required double pinTop,
  required double viewportBottom,
}) {
  final current = currentTranscriptStickyIndex(openers: openers, pinTop: pinTop);
  if (current < 0 || !fullHeights.containsKey(openers[current].id)) return TranscriptStickyLayout.empty;
  // A built bubble's own height decides: a copy of a pasted document holds
  // only its end, which can be far shorter than the bubble.
  bool showsEnd({required TranscriptStickyOpener opener}) {
    final height = switch (opener.place) {
      TranscriptStickyBuilt(:final top, :final bottom) => bottom - top,
      TranscriptStickyAbove() || TranscriptStickyBelow() => fullHeights[opener.id] ?? 0,
    };
    return height > viewportBottom - pinTop;
  }

  final pinned = <TranscriptPinnedPrompt>[];
  for (final index in [current - 1, current]) {
    if (index < 0) continue;
    final opener = openers[index];
    final fullHeight = fullHeights[opener.id];
    if (fullHeight == null) continue;
    final compact = min(fullHeight, compactHeight);
    final end = showsEnd(opener: opener);
    // A tall bubble is still being read until its end reaches the pin.
    if (opener.place case TranscriptStickyBuilt(:final bottom) when end && bottom - pinTop > compact) continue;
    final (height, underElevation) = switch (opener.place) {
      TranscriptStickyBuilt(:final bottom) => (
        max(compact, bottom - pinTop),
        ((pinTop + compact - bottom) / 28).clamp(0.0, 1.0),
      ),
      TranscriptStickyAbove() || TranscriptStickyBelow() => (compact, 1.0),
    };
    final nextTop = switch (openers.elementAtOrNull(index + 1)?.place) {
      TranscriptStickyAbove() => double.negativeInfinity,
      TranscriptStickyBuilt(:final top) => top,
      TranscriptStickyBelow() || null => double.infinity,
    };
    final top = min(pinTop, nextTop - transcriptStickyGap - height);
    if (top + height <= -transcriptStickyHaloReach) continue;
    final pushElevation = ((nextTop - transcriptStickyGap - pinTop - height) / 40).clamp(0.0, 1.0);
    pinned.add((
      openerId: opener.id,
      top: top,
      height: height,
      fullHeight: fullHeight,
      elevation: underElevation * pushElevation,
      view: end ? TranscriptPinEnd(fade: underElevation) : const TranscriptPinStart(),
    ));
  }
  return TranscriptStickyLayout(
    pinned: pinned,
    hiddenOpenerIds: {
      for (final opener in openers.take(current + 1))
        if (opener.place is TranscriptStickyBuilt && !showsEnd(opener: opener)) opener.id,
    },
  );
}
