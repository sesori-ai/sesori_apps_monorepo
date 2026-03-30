import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_navigator_of_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidNavigatorOfTest);
  });
}

@reflectiveTest
class AvoidNavigatorOfTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidNavigatorOfRule();
    super.setUp();
  }

  void test_reportForNavigatorOf() async {
    await assertDiagnostics(r'''
class Navigator {
  static dynamic of(dynamic context, {bool rootNavigator = false}) => null;
}

void navigate(dynamic context) {
  Navigator.of(context);
}
''', [lint(132, 21)]);
  }

  void test_reportForNavigatorOfWithRootNavigator() async {
    await assertDiagnostics(r'''
class Navigator {
  static dynamic of(dynamic context, {bool rootNavigator = false}) => null;
}

void navigate(dynamic context) {
  Navigator.of(context, rootNavigator: true);
}
''', [lint(132, 42)]);
  }

  void test_noErrorForOtherNavigatorMembers() async {
    await assertNoDiagnostics(r'''
class Navigator {
  static bool get canPop => false;
}

void foo() {
  final canPop = Navigator.canPop;
}
''');
  }
}
