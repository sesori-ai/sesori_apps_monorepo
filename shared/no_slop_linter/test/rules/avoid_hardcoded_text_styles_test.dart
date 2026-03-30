import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_hardcoded_text_styles_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidHardcodedTextStylesTest);
  });
}

@reflectiveTest
class AvoidHardcodedTextStylesTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidHardcodedTextStylesRule();
    super.setUp();
  }

  void test_reportForTextStyleConstructor() async {
    await assertDiagnostics(r'''
class TextStyle {
  const TextStyle({double? fontSize});
}
final style = TextStyle(fontSize: 16);
''', [lint(73, 23)]);
  }

  void test_noErrorForNonTextStyleClass() async {
    await assertNoDiagnostics(r'''
class MyStyle {
  const MyStyle({double? fontSize});
}
final style = MyStyle(fontSize: 16);
''');
  }

  void test_reportOnlyForBaseStyleInMerge() async {
    await assertDiagnostics(r'''
class TextStyle {
  const TextStyle({double? fontSize, int? fontWeight});
  TextStyle merge(TextStyle? other) => this;
}
final baseStyle = TextStyle(fontSize: 14);
final merged = baseStyle.merge(TextStyle(fontWeight: 700));
''', [lint(139, 23)]);
  }

  void test_reportOnlyForBaseStyleInCopyWith() async {
    await assertDiagnostics(r'''
class TextStyle {
  const TextStyle({double? fontSize, int? color});
  TextStyle copyWith({double? fontSize, int? color}) => this;
}
final baseStyle = TextStyle(fontSize: 14);
final modified = baseStyle.copyWith(color: 0xFF000000);
''', [lint(151, 23)]);
  }
}
