import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_as_cast_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidAsCastTest);
  });
}

@reflectiveTest
class AvoidAsCastTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidAsCastRule();
    super.setUp();
  }

  void test_reportForForceCast() async {
    await assertDiagnostics(r'''
void foo(Object obj) {
  final str = obj as String;
}
''', [lint(37, 13)]);
  }

  void test_reportForForceCastInExpression() async {
    await assertDiagnostics(r'''
void foo(List<Object> list) {
  final length = (list[0] as String).length;
}
''', [lint(48, 17)]);
  }

  void test_reportForNullableTypeCast() async {
    await assertDiagnostics(r'''
void foo(Object obj) {
  final str = obj as String?;
}
''', [lint(37, 14)]);
  }

  void test_noErrorForIsCheck() async {
    await assertNoDiagnostics(r'''
void foo(Object obj) {
  if (obj is String) {
    print(obj.length);
  }
}
''');
  }

  void test_noErrorForPatternMatching() async {
    await assertNoDiagnostics(r'''
void foo(Object obj) {
  switch (obj) {
    case String s:
      print(s.length);
  }
}
''');
  }
}
