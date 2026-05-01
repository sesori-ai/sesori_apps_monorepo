import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/prefer_exhaustive_switch_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferExhaustiveSwitchTest);
  });
}

@reflectiveTest
class PreferExhaustiveSwitchTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = PreferExhaustiveSwitchRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForEnumSwitchWithDefault() async {
    await assertDiagnostics(r'''
enum Status { active, inactive }
void foo(Status status) {
  switch (status) {
    case Status.active:
      print('active');
      break;
    default:
      print('other');
  }
}
''', [lint(143, 30)]);
  }

  void test_reportForSealedClassSwitchWithWildcard() async {
    await assertDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  _ => 'other',
};
''', [lint(158, 12)]);
  }

  void test_noErrorForExhaustiveEnumSwitch() async {
    await assertNoDiagnostics(r'''
enum Status { active, inactive }
void foo(Status status) {
  switch (status) {
    case Status.active:
      print('active');
      break;
    case Status.inactive:
      print('inactive');
      break;
  }
}
''');
  }

  void test_noErrorForStringSwitchWithDefault() async {
    await assertNoDiagnostics(r'''
void foo(String value) {
  switch (value) {
    case 'a':
      print('a');
      break;
    default:
      print('other');
  }
}
''');
  }

  void test_noErrorForIntSwitchWithDefault() async {
    await assertNoDiagnostics(r'''
void foo(int value) {
  switch (value) {
    case 1:
      print('one');
      break;
    default:
      print('other');
  }
}
''');
  }

  void test_noErrorForObjectSwitchWithWildcard() async {
    await assertNoDiagnostics(r'''
String describe(Object obj) => switch (obj) {
  String s => 'string: $s',
  int i => 'int: $i',
  _ => 'other',
};
''');
  }

  void test_noErrorForDoubleSwitchWithWildcard() async {
    await assertNoDiagnostics(r'''
extension DoubleExt on double {
  String format() => switch (this) {
    < 1e-6 => '8 decimals',
    < 1e-5 => '7 decimals',
    < 1e-4 => '6 decimals',
    _ => '0 decimals',
  };
}
''');
  }

  void test_noErrorForNumSwitchWithWildcard() async {
    await assertNoDiagnostics(r'''
String describeNum(num n) => switch (n) {
  < 0 => 'negative',
  == 0 => 'zero',
  _ => 'positive',
};
''');
  }

  void test_noErrorForExhaustiveSealedClassSwitch() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  Failure() => 'failure',
};
''');
  }
}
