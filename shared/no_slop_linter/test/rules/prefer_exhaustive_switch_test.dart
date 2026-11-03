import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
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
    await assertDiagnostics(
      r'''
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
''',
      [lint(143, 30)],
    );
  }

  void test_reportForSealedClassSwitchWithWildcard() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  _ => 'other',
};
''',
      [lint(158, 12)],
    );
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

  void test_reportForEnumSwitchStatementWithWildcardCase() async {
    await assertDiagnostics(
      r'''
enum Status { active, inactive }
void foo(Status status) {
  switch (status) {
    case Status.active:
      print('active');
    case _:
      print('other');
  }
}
''',
      [lint(130, 29)],
    );
  }

  void test_noErrorForEnumSwitchStatementWithGuardedWildcardCase() async {
    await assertNoDiagnostics(r'''
enum Status { active, inactive }
void foo(Status status, bool verbose) {
  switch (status) {
    case _ when verbose:
      print('verbose');
    case Status.active:
      print('active');
    case Status.inactive:
      print('inactive');
  }
}
''');
  }

  void test_noErrorForSealedClassSwitchWithGuardedWildcard() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r, bool verbose) => switch (r) {
  _ when verbose => 'verbose',
  Success() => 'success',
  Failure() => 'failure',
};
''');
  }

  void test_reportForSealedClassSwitchWithFinalVariable() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  final other => '$other',
};
''',
      [lint(158, 23)],
    );
  }

  void test_reportForSealedClassSwitchWithVarVariable() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  var other => '$other',
};
''',
      [lint(158, 21)],
    );
  }

  void test_reportForEnumSwitchStatementWithFinalVariableCase() async {
    await assertDiagnostics(
      r'''
enum Status { active, inactive }
void foo(Status status) {
  switch (status) {
    case Status.active:
      print('active');
    case final other:
      print(other);
  }
}
''',
      [lint(130, 37)],
    );
  }

  void test_noErrorForSealedClassSwitchWithGuardedFinalVariable() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r, bool verbose) => switch (r) {
  final value when verbose => '$value',
  Success() => 'success',
  Failure() => 'failure',
};
''');
  }

  void test_reportForSealedClassSwitchWithVariableTypedAsScrutinee() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  final Result other => '$other',
};
''',
      [lint(158, 30)],
    );
  }

  void test_reportForNullableSealedClassSwitchWithNonNullableVariable() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result? r) => switch (r) {
  null => 'none',
  Success() => 'success',
  Result other => '$other',
};
''',
      [lint(177, 24)],
    );
  }

  void test_reportForSealedClassSwitchWithWildcardTypedAsScrutinee() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  Result _ => 'other',
};
''',
      [lint(158, 19)],
    );
  }

  void test_reportForSealedClassSwitchWithWildcardTypedAsSupertype() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success() => 'success',
  Object _ => 'other',
};
''',
      [lint(158, 19)],
    );
  }

  void test_noErrorForSealedClassSwitchWithSubtypeVariables() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result r) => switch (r) {
  Success _ => 'success',
  final Failure failure => '$failure',
};
''');
  }

  void test_noErrorForSealedClassSwitchStatementWithSubtypeVariableCases() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

void foo(Result r) {
  switch (r) {
    case Success _:
      print('success');
    case final Failure failure:
      print(failure);
  }
}
''');
  }

  void test_reportForSealedClassSwitchStatementWithObjectPatternOfScrutineeType() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

void foo(Result r) {
  switch (r) {
    case Success():
      print('success');
    case Result():
      break;
  }
}
''',
      [lint(172, 27)],
    );
  }

  void test_reportForSealedClassSwitchWithObjectPatternBindingFields() async {
    await assertDiagnostics(
      r'''
sealed class Result {
  int get code;
}
class Success extends Result {
  @override
  int get code => 0;
}
class Failure extends Result {
  @override
  int get code => 1;
}

String describe(Result r) => switch (r) {
  Success() => 'success',
  Result(:final code) => '$code',
};
''',
      [lint(243, 30)],
    );
  }

  void test_noErrorForSealedClassSwitchWithObjectPatternMatchingAField() async {
    await assertNoDiagnostics(r'''
sealed class Result {
  int get code;
}
class Success extends Result {
  @override
  int get code => 0;
}
class Failure extends Result {
  @override
  int get code => 1;
}

String describe(Result r) => switch (r) {
  Result(code: 0) => 'zero',
  Success() => 'success',
  Failure() => 'failure',
};
''');
  }

  void test_reportForNullableSealedClassSwitchWithNullCheckVariable() async {
    await assertDiagnostics(
      r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result? r) => switch (r) {
  Success() => 'success',
  final other? => '$other',
  null => 'none',
};
''',
      [lint(159, 24)],
    );
  }

  void test_noErrorForNullableEnumSwitchThatOnlyChecksNull() async {
    await assertNoDiagnostics(r'''
enum Status { active, inactive }
String describe(Status? status) => switch (status) {
  null => 'none',
  final value => value.name,
};
''');
  }

  void test_noErrorForNullableSealedClassSwitchThatOnlyChecksNullWithNullCheck() async {
    await assertNoDiagnostics(r'''
sealed class Result {}
class Success extends Result {}
class Failure extends Result {}

String describe(Result? r) => switch (r) {
  final value? => '$value',
  null => 'none',
};
''');
  }

  void test_noErrorForNullableEnumSwitchStatementThatOnlyChecksNull() async {
    await assertNoDiagnostics(r'''
enum Status { active, inactive }
void foo(Status? status) {
  switch (status) {
    case null:
      print('none');
    case final value:
      print(value);
  }
}
''');
  }

  void test_noErrorForObjectSwitchStatementWithFinalVariableCase() async {
    await assertNoDiagnostics(r'''
void foo(Object value) {
  switch (value) {
    case String s:
      print(s);
    case final other:
      print(other);
  }
}
''');
  }
}
