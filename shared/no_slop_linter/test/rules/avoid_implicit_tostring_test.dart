import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/utils/no_slop_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_implicit_tostring_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidImplicitTostringTest);
  });
}

@reflectiveTest
class AvoidImplicitTostringTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidImplicitTostringRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportForObjectInInterpolation() async {
    await assertDiagnostics(r'''
class User {
  final String name;
  User(this.name);
}

void main() {
  final user = User('John');
  final msg = 'User: $user';
  print(msg);
}
''', [lint(121, 4)]);
  }

  void test_reportForObjectInInterpolationWithBraces() async {
    await assertDiagnostics(r'''
class Widget {}

void main() {
  final widget = Widget();
  final msg = 'Widget: ${widget}';
  print(msg);
}
''', [lint(83, 6)]);
  }

  void test_noErrorForStringType() async {
    await assertNoDiagnostics(r'''
void main() {
  final name = 'Alice';
  final msg = 'Name: $name';
  print(msg);
}
''');
  }

  void test_noErrorForIntType() async {
    await assertNoDiagnostics(r'''
void main() {
  final count = 42;
  final msg = 'Count: $count';
  print(msg);
}
''');
  }

  void test_noErrorForDoubleType() async {
    await assertNoDiagnostics(r'''
void main() {
  final price = 19.99;
  final msg = 'Price: $price';
  print(msg);
}
''');
  }

  void test_noErrorForBoolType() async {
    await assertNoDiagnostics(r'''
void main() {
  final flag = true;
  final msg = 'Flag: $flag';
  print(msg);
}
''');
  }

  void test_noErrorForExplicitToString() async {
    await assertNoDiagnostics(r'''
class User {
  final String name;
  User(this.name);
}

void main() {
  final user = User('John');
  final msg = 'User: ${user.toString()}';
  print(msg);
}
''');
  }

  void test_noErrorForAccessingStringProperty() async {
    await assertNoDiagnostics(r'''
class User {
  final String name;
  User(this.name);
}

void main() {
  final user = User('John');
  final msg = 'User name: ${user.name}';
  print(msg);
}
''');
  }

  void test_noErrorInsideLogtCall() async {
    await assertNoDiagnostics(r'''
class User {
  final String name;
  User(this.name);
}

void logt(String message) {}

void main() {
  final user = User('John');
  logt('User: $user');
}
''');
  }

  void test_noErrorInsideLogdCall() async {
    await assertNoDiagnostics(r'''
class Widget {}

void logd(String message) {}

void main() {
  final widget = Widget();
  logd('Widget: ${widget}');
}
''');
  }

  void test_noErrorForStringGetter() async {
    await assertNoDiagnostics(r'''
class User {
  final String _name;
  User(this._name);

  String get displayName => _name;
}

void main() {
  final user = User('John');
  final msg = 'Name: ${user.displayName}';
  print(msg);
}
''');
  }

  void test_noErrorForTopLevelFunctionReturningString() async {
    await assertNoDiagnostics(r'''
String getName() => 'Alice';

void main() {
  final msg = 'Name: ${getName()}';
  print(msg);
}
''');
  }

  void test_noErrorForMethodReturningString() async {
    await assertNoDiagnostics(r'''
class User {
  final String name;
  User(this.name);

  String getGreeting() => 'Hello, $name';
}

void main() {
  final user = User('John');
  final msg = 'Greeting: ${user.getGreeting()}';
  print(msg);
}
''');
  }

  void test_noErrorForNullableStringGetter() async {
    await assertNoDiagnostics(r'''
class User {
  final String? nickname;
  User({this.nickname});
}

void main() {
  final user = User(nickname: 'Johnny');
  final msg = 'Nick: ${user.nickname}';
  print(msg);
}
''');
  }

  void test_noErrorForNullableStringVariable() async {
    await assertNoDiagnostics(r'''
void main() {
  final String? name = 'Alice';
  final msg = 'Name: $name';
  print(msg);
}
''');
  }

  void test_noErrorForStaticMethodReturningString() async {
    await assertNoDiagnostics(r'''
class Helper {
  static String format(int value) => '$value items';
}

void main() {
  final msg = 'Result: ${Helper.format(5)}';
  print(msg);
}
''');
  }

  void test_reportInNonLoggingFunction() async {
    await assertDiagnostics(r'''
class User {
  final String name;
  User(this.name);
}

void logt(String message) {}

void main() {
  final user = User('John');
  logt('User: $user');
  print('User: $user');
}
''', [lint(168, 4)]);
  }
}
