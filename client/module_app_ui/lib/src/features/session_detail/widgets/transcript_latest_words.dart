import "dart:math";

import "package:material_ui/material_ui.dart";

/// One line holding the end of streaming [text] under a live row: the newest
/// words stay in view and the older start fades out at the leading edge.
class const TranscriptLatestWords({super.key, required final String text, required final TextStyle style})
    extends StatelessWidget {
  /// How much of the end of the text the line considers; more than one line
  /// holds, so the line stays full, without laying out the whole accumulated
  /// document on every flush.
  static const int _kLatestWordsChars = 160;

  /// The latest words of streaming text, on one line.
  @visibleForTesting
  static String latestWords({required String text}) {
    var start = max(0, text.length - _kLatestWordsChars);
    // Never start on the low half of a UTF-16 surrogate pair (emoji etc.):
    // an orphaned low surrogate renders as a replacement character.
    if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) start++;
    return text.substring(start).replaceAll(RegExp(r"\s+"), " ").trim();
  }

  static bool _isLowSurrogate(int codeUnit) => (codeUnit & 0xFC00) == 0xDC00;

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
