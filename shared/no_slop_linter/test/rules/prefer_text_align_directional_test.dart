import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_text_align_directional_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferTextAlignDirectionalTest);
  });
}

@reflectiveTest
class PreferTextAlignDirectionalTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferTextAlignDirectionalRule();
    super.setUp();
  }

  void test_reportForTextAlignLeft() async {
    await assertDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }
final align = TextAlign.left;
''', [lint(74, 14)]);
  }

  void test_reportForTextAlignRight() async {
    await assertDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }
final align = TextAlign.right;
''', [lint(74, 15)]);
  }

  void test_noErrorForTextAlignStart() async {
    await assertNoDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }
final align = TextAlign.start;
''');
  }

  void test_noErrorForTextAlignEnd() async {
    await assertNoDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }
final align = TextAlign.end;
''');
  }

  void test_noErrorForTextAlignCenter() async {
    await assertNoDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }
final align = TextAlign.center;
''');
  }

  void test_noErrorForTextAlignLeftRightInSwitchExpression() async {
    await assertNoDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }

enum WrapAlignment { start, end, center }

WrapAlignment convert(TextAlign align) => switch (align) {
  TextAlign.left => WrapAlignment.start,
  TextAlign.right => WrapAlignment.end,
  TextAlign.start => WrapAlignment.start,
  TextAlign.end => WrapAlignment.end,
  TextAlign.center => WrapAlignment.center,
  TextAlign.justify => WrapAlignment.center,
};
''');
  }

  void test_noErrorForTextAlignLeftRightInSwitchStatement() async {
    await assertNoDiagnostics(r'''
enum TextAlign { left, right, start, end, center, justify }

String describe(TextAlign align) {
  switch (align) {
    case TextAlign.left:
      return 'left';
    case TextAlign.right:
      return 'right';
    case TextAlign.start:
      return 'start';
    case TextAlign.end:
      return 'end';
    case TextAlign.center:
      return 'center';
    case TextAlign.justify:
      return 'justify';
  }
}
''');
  }
}
