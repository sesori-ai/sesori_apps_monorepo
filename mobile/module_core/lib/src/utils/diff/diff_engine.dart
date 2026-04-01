import "package:diff_match_patch/diff_match_patch.dart" as dmp;

enum DiffLineType { added, removed, context }

class DiffLine {
  final DiffLineType type;
  final int? oldLineNumber;
  final int? newLineNumber;
  final String content;

  const DiffLine({
    required this.type,
    this.oldLineNumber,
    this.newLineNumber,
    required this.content,
  });
}

class DiffHunk {
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;

  String get header => "@@ -$oldStart,$oldCount +$newStart,$newCount @@";

  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });
}

class DiffFileResult {
  final List<DiffHunk> hunks;
  final int additions;
  final int deletions;

  const DiffFileResult({
    required this.hunks,
    required this.additions,
    required this.deletions,
  });
}

class DiffEngine {
  static const int _contextLines = 3;

  static DiffFileResult computeDiff({required String before, required String after}) {
    final lineMode = _linesToChars(before, after);
    final chars1 = lineMode.chars1;
    final chars2 = lineMode.chars2;
    final lineArray = lineMode.lineArray;
    final diffs = dmp.diff(chars1, chars2, checklines: false, timeout: 0);
    _charsToLines(diffs, lineArray);

    final lines = <DiffLine>[];
    var oldLine = 1;
    var newLine = 1;

    for (final diff in diffs) {
      final chunkLines = _splitLines(diff.text);
      for (final content in chunkLines) {
        if (diff.operation == dmp.DIFF_EQUAL) {
          lines.add(
            DiffLine(
              type: DiffLineType.context,
              oldLineNumber: oldLine,
              newLineNumber: newLine,
              content: content,
            ),
          );
          oldLine++;
          newLine++;
          continue;
        }

        if (diff.operation == dmp.DIFF_DELETE) {
          lines.add(
            DiffLine(
              type: DiffLineType.removed,
              oldLineNumber: oldLine,
              newLineNumber: null,
              content: content,
            ),
          );
          oldLine++;
          continue;
        }

        if (diff.operation == dmp.DIFF_INSERT) {
          lines.add(
            DiffLine(
              type: DiffLineType.added,
              oldLineNumber: null,
              newLineNumber: newLine,
              content: content,
            ),
          );
          newLine++;
        }
      }
    }

    final additions = lines.where((line) => line.type == DiffLineType.added).length;
    final deletions = lines.where((line) => line.type == DiffLineType.removed).length;
    final hunks = _buildHunks(lines);
    return DiffFileResult(hunks: hunks, additions: additions, deletions: deletions);
  }

  static List<String> _splitLines(String text) {
    if (text.isEmpty) {
      return const [];
    }

    final parts = text.split("\n");
    if (text.endsWith("\n")) {
      parts.removeLast();
    }
    return parts;
  }

  static ({String chars1, String chars2, List<String> lineArray}) _linesToChars(
    String before,
    String after,
  ) {
    final lineArray = <String>[""];
    final lineLookup = <String, int>{};
    final chars1 = _encodeLines(before, lineArray, lineLookup);
    final chars2 = _encodeLines(after, lineArray, lineLookup);
    return (chars1: chars1, chars2: chars2, lineArray: lineArray);
  }

  static String _encodeLines(
    String text,
    List<String> lineArray,
    Map<String, int> lineLookup,
  ) {
    var start = 0;
    var end = -1;
    final chars = StringBuffer();

    while (end < text.length - 1) {
      end = text.indexOf("\n", start);
      if (end == -1) {
        end = text.length - 1;
      }

      final line = text.substring(start, end + 1);
      start = end + 1;

      final existing = lineLookup[line];
      if (existing != null) {
        chars.writeCharCode(existing);
        continue;
      }

      lineArray.add(line);
      final index = lineArray.length - 1;
      lineLookup[line] = index;
      chars.writeCharCode(index);
    }

    return chars.toString();
  }

  static void _charsToLines(List<dmp.Diff> diffs, List<String> lineArray) {
    for (final diff in diffs) {
      final text = StringBuffer();
      for (final rune in diff.text.runes) {
        text.write(lineArray[rune]);
      }
      diff.text = text.toString();
    }
  }

  static List<DiffHunk> _buildHunks(List<DiffLine> allLines) {
    final changedIndexes = <int>[];
    for (var i = 0; i < allLines.length; i++) {
      if (allLines[i].type != DiffLineType.context) {
        changedIndexes.add(i);
      }
    }

    if (changedIndexes.isEmpty) {
      return const [];
    }

    final ranges = <({int start, int end})>[];
    for (final index in changedIndexes) {
      final nextStart = index - _contextLines < 0 ? 0 : index - _contextLines;
      final maxIndex = allLines.length - 1;
      final nextEnd = index + _contextLines > maxIndex ? maxIndex : index + _contextLines;

      if (ranges.isEmpty) {
        ranges.add((start: nextStart, end: nextEnd));
        continue;
      }

      final last = ranges.last;
      if (nextStart <= last.end + 1) {
        ranges[ranges.length - 1] = (
          start: last.start,
          end: nextEnd > last.end ? nextEnd : last.end,
        );
        continue;
      }

      ranges.add((start: nextStart, end: nextEnd));
    }

    final hunks = <DiffHunk>[];
    for (final range in ranges) {
      final hunkLines = allLines.sublist(range.start, range.end + 1);
      final oldNumbers = hunkLines
          .where((line) => line.oldLineNumber != null)
          .map((line) => line.oldLineNumber!)
          .toList();
      final newNumbers = hunkLines
          .where((line) => line.newLineNumber != null)
          .map((line) => line.newLineNumber!)
          .toList();

      final oldStart = oldNumbers.isNotEmpty ? oldNumbers.first : ((hunkLines.first.newLineNumber ?? 1) - 1);
      final newStart = newNumbers.isNotEmpty ? newNumbers.first : ((hunkLines.first.oldLineNumber ?? 1) - 1);

      hunks.add(
        DiffHunk(
          oldStart: oldStart,
          oldCount: oldNumbers.length,
          newStart: newStart,
          newCount: newNumbers.length,
          lines: hunkLines,
        ),
      );
    }

    return hunks;
  }
}
