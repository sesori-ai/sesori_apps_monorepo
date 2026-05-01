import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_hardcoded_colors_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidHardcodedColorsTest);
  });
}

@reflectiveTest
class AvoidHardcodedColorsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidHardcodedColorsRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForColorConstructor() async {
    await assertDiagnostics(r'''
class Color {
  const Color(int value);
}
final color = Color(0xFF000000);
''', [lint(56, 17)]);
  }

  void test_reportForColorsConstant() async {
    await assertDiagnostics(r'''
class Colors {
  static const red = 0;
}
final color = Colors.red;
''', [lint(55, 10)]);
  }

  void test_noErrorForNonColorClass() async {
    await assertNoDiagnostics(r'''
class MyClass {
  const MyClass(int value);
}
final obj = MyClass(123);
''');
  }

  void test_noErrorForNonColorsPrefix() async {
    await assertNoDiagnostics(r'''
class Theme {
  static const primary = 0;
}
final color = Theme.primary;
''');
  }
}
