import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_string_literals_in_widgets_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidStringLiteralsInWidgetsTest);
  });
}

@reflectiveTest
class AvoidStringLiteralsInWidgetsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidStringLiteralsInWidgetsRule();
    super.setUp();
  }

  void test_reportForTextWithHardcodedString() async {
    await assertDiagnostics(r'''
class Text {
  const Text(String data);
}
final widget = Text('Hello World');
''', [lint(62, 13)]);
  }

  void test_reportForTextWithDoubleQuotedString() async {
    await assertDiagnostics(r'''
class Text {
  const Text(String data);
}
final widget = Text("Welcome back!");
''', [lint(62, 15)]);
  }

  void test_noErrorForTextWithVariable() async {
    await assertNoDiagnostics(r'''
class Text {
  const Text(String data);
}
final message = 'Hello';
final widget = Text(message);
''');
  }

  void test_noErrorForTextWithEmptyString() async {
    await assertNoDiagnostics(r'''
class Text {
  const Text(String data);
}
final widget = Text('');
''');
  }

  void test_noErrorForTextWithSingleCharacter() async {
    await assertNoDiagnostics(r'''
class Text {
  const Text(String data);
}
final widget = Text('x');
''');
  }

  void test_noErrorForNonTextClass() async {
    await assertNoDiagnostics(r'''
class Label {
  const Label(String data);
}
final widget = Label('Hello World');
''');
  }
}
