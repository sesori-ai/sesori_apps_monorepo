import "dart:math";

import "package:material_ui/material_ui.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/markdown_plain_text.dart";
import "transcript_motion.dart";

/// A live row's trailing slot: the latest words of streaming [text] fade in
/// and out on the label's line, so they never change the row's height.
/// Anchored at the line's end from the first word, so the newest words stay
/// put while anything before them, such as a timer, changes width.
class const TranscriptTrailingLatestWords({super.key, required final String? text, required final TextStyle style})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return AnimatedSwitcher(
      duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
      layoutBuilder: (current, previous) =>
          Stack(alignment: AlignmentDirectional.centerEnd, children: [...previous, ?current]),
      child: text == null || text.isEmpty
          ? const SizedBox.shrink()
          : TranscriptLatestWords(key: const ValueKey("latestWords"), text: text, style: style),
    );
  }
}

/// One line holding the end of streaming [text]: the newest words stay in
/// view and the older start fades out at the leading edge.
class const TranscriptLatestWords({super.key, required final String text, required final TextStyle style})
    extends StatelessWidget {
  /// How much of the end of the text the line considers; more than one line
  /// holds, so the line stays full, without laying out the whole accumulated
  /// document on every flush.
  static const int _kLatestWordsChars = 160;

  /// The latest words of streaming Markdown [text], on one line, as they
  /// render: emphasis markers and backticks are resolved, not shown.
  @visibleForTesting
  static String latestWords({required String text}) {
    // Parse from the start of a line, so the window never opens between the
    // two markers of a pair and leaves the closing one behind as text.
    final windowStart = max(0, text.length - _kLatestWordsChars);
    final lineStart = windowStart == 0 ? 0 : text.lastIndexOf("\n", windowStart) + 1;
    final plain = markdownPlainText(markdown: _withoutOpenEmphasis(text.substring(lineStart)), nameImage: null);
    var start = max(0, plain.length - _kLatestWordsChars);
    // Never start on the low half of a UTF-16 surrogate pair (emoji etc.):
    // an orphaned low surrogate renders as a replacement character.
    if (start > 0 && _isLowSurrogate(plain.codeUnitAt(start))) start++;
    return plain.substring(start).replaceAll(RegExp(r"\s+"), " ").trim();
  }

  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;

  /// [markdown] without the opening marker of an emphasis still streaming on
  /// its last line, such as a title arriving as `**Planning th`: until the
  /// closing marker comes, the parser can only show the marker as text. Only a
  /// marker that starts the line is dropped, so a code span is never touched.
  static String _withoutOpenEmphasis(String markdown) {
    final lastLineStart = markdown.lastIndexOf("\n") + 1;
    final line = markdown.substring(lastLineStart);
    final match = _openEmphasis.firstMatch(line);
    final marker = match?[2];
    if (match == null || marker == null || line.contains(marker, match.end)) return markdown;
    return "${markdown.substring(0, lastLineStart)}${match[1] ?? ""}${line.substring(match.end)}";
  }

  /// An emphasis marker at the start of a line, directly before a word; a list
  /// bullet has a space after it.
  static final RegExp _openEmphasis = RegExp(r"^(\s*)(\*\*|__|\*|_)(?=[^\s*_])");

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [Colors.transparent, Colors.white],
        stops: [0.0, 0.15],
      ).createShader(bounds, textDirection: direction),
      blendMode: BlendMode.dstIn,
      child: UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        alignment: AlignmentDirectional.centerEnd,
        clipBehavior: Clip.hardEdge,
        child: Text(latestWords(text: text), maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}
