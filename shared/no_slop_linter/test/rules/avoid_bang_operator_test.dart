import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_bang_operator_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidBangOperatorTest);
  });
}

@reflectiveTest
class AvoidBangOperatorTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidBangOperatorRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForBangOnVariable() async {
    await assertDiagnostics(r'''
void main() {
  String? nullableString;
  final value = nullableString!;
  print(value);
}
''', [lint(70, 1)]);
  }

  void test_reportForBangInMethodChain() async {
    await assertDiagnostics(r'''
void main() {
  String? nullableString;
  print(nullableString!.length);
}
''', [lint(62, 1)]);
  }

  void test_reportForMultipleBangOperators() async {
    await assertDiagnostics(r'''
void main() {
  String? a;
  String? b;
  print(a!);
  print(b!);
}
''', [lint(49, 1), lint(62, 1)]);
  }

  void test_noErrorForNullCheck() async {
    await assertNoDiagnostics(r'''
void foo(String? nullableString) {
  if (nullableString != null) {
    print(nullableString);
  }
}
''');
  }

  void test_noErrorForNullCoalescing() async {
    await assertNoDiagnostics(r'''
void main() {
  String? nullableString;
  final value = nullableString ?? 'default';
  print(value);
}
''');
  }

  void test_noErrorForNullAware() async {
    await assertNoDiagnostics(r'''
void foo(String? nullableString) {
  final length = nullableString?.length;
  print(length);
}
''');
  }
}
