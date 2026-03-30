import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_size_const_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferSizeConstTest);
  });
}

@reflectiveTest
class PreferSizeConstTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferSizeConstRule();
    super.setUp();
  }

  void test_reportForSizedBoxWithHardcodedHeight() async {
    await assertDiagnostics(r'''
class SizedBox {
  const SizedBox({double? height, double? width});
}
final widget = SizedBox(height: 16);
''', [lint(94, 10)]);
  }

  void test_reportForSizedBoxWithHardcodedWidth() async {
    await assertDiagnostics(r'''
class SizedBox {
  const SizedBox({double? height, double? width});
}
final widget = SizedBox(width: 8);
''', [lint(94, 8)]);
  }

  void test_reportForGapWithHardcodedValue() async {
    await assertDiagnostics(r'''
class Gap {
  const Gap(double size);
}
final widget = Gap(16);
''', [lint(59, 2)]);
  }

  void test_noErrorForSizedBoxWithConstantReference() async {
    await assertNoDiagnostics(r'''
class SizedBox {
  const SizedBox({double? height, double? width});
}
const spacing = 16.0;
final widget = SizedBox(height: spacing);
''');
  }

  void test_noErrorForNonSizedBoxClass() async {
    await assertNoDiagnostics(r'''
class MyBox {
  const MyBox({double? height, double? width});
}
final widget = MyBox(height: 16);
''');
  }
}
