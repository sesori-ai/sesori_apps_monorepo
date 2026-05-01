import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_raw_go_router_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidRawGoRouterTest);
  });
}

@reflectiveTest
class AvoidRawGoRouterTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidRawGoRouterRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForContextGo() async {
    await assertDiagnostics(r'''
class BuildContext {}
extension _ on BuildContext {
  void go(String path) {}
}

void foo(BuildContext context) {
  context.go('/path');
}
''', [lint(116, 19)]);
  }

  void test_reportForContextPush() async {
    await assertDiagnostics(r'''
class BuildContext {}
extension _ on BuildContext {
  void push(String path) {}
}

void foo(BuildContext context) {
  context.push('/path');
}
''', [lint(118, 21)]);
  }

  void test_reportForContextGoNamed() async {
    await assertDiagnostics(r'''
class BuildContext {}
extension _ on BuildContext {
  void goNamed(String name) {}
}

void foo(BuildContext context) {
  context.goNamed('route');
}
''', [lint(121, 24)]);
  }

  void test_reportForGoRouterOfGo() async {
    await assertDiagnostics(r'''
class GoRouter {
  static GoRouter of(dynamic context) => GoRouter();
  static GoRouter? maybeOf(dynamic context) => GoRouter();
  void go(String path) {}
}

void foo(dynamic context) {
  GoRouter.of(context).go('/path');
}
''', [lint(188, 20), lint(188, 32)]);
  }

  void test_reportForGoRouterMaybeOfPush() async {
    await assertDiagnostics(r'''
class GoRouter {
  static GoRouter of(dynamic context) => GoRouter();
  static GoRouter? maybeOf(dynamic context) => GoRouter();
  void push(String path) {}
}

void foo(dynamic context) {
  GoRouter.maybeOf(context)?.push('/path');
}
''', [lint(190, 25), lint(190, 40)]);
  }

  void test_noErrorForContextPop() async {
    await assertNoDiagnostics(r'''
class BuildContext {}
extension _ on BuildContext {
  void pop() {}
}

void foo(BuildContext context) {
  context.pop();
}
''');
  }

  void test_noErrorForUriReplace() async {
    await assertNoDiagnostics(r'''
class MyUri {
  static MyUri parse(String s) => MyUri();
  MyUri replace({Map<String, String>? queryParameters}) => MyUri();
}

void foo() {
  final uri = MyUri.parse('https://example.com').replace(
    queryParameters: {'key': 'value'},
  );
  print(uri);
}
''');
  }

  void test_noErrorForStringReplace() async {
    await assertNoDiagnostics(r'''
class MyString {
  MyString replaceAll(String from, String to) => MyString();
}

void foo() {
  final result = MyString().replaceAll('h', 'j');
  print(result);
}
''');
  }

  void test_noErrorForListReplace() async {
    await assertNoDiagnostics(r'''
class MyList {
  MyList replaceRange(int start, int end, List<int> replacement) => MyList();
}

void foo() {
  final list = MyList();
  final result = list.replaceRange(0, 1, [4]);
  print(result);
}
''');
  }
}
