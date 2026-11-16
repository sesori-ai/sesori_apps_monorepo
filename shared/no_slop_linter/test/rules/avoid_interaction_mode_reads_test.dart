import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/package_config_file_builder.dart';
import 'package:no_slop_linter/src/rules/avoid_interaction_mode_reads_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidInteractionModeReadsTest);
  });
}

const _scope = "import 'package:theme_prego/interactions/prego_interaction_scope.dart';";
const _designSystem = "import 'package:theme_prego/theme/prego_design_system.dart';";
const _composer = "import 'package:sesori_app_ui/src/features/session_detail/composer_presentation_scope.dart';";
const _imports = '$_scope\n$_designSystem\n$_composer\n';

/// The package under test (`test`) stands in for a product shell. Fake
/// `theme_prego` and `sesori_app_ui` packages sit inside it, so their files
/// are analysed too.
@reflectiveTest
class AvoidInteractionModeReadsTest extends AnalysisRuleTest {
  String get _themePrego => '$testPackageRootPath/theme_prego';

  String get _appUi => '$testPackageRootPath/sesori_app_ui';

  String get _sharedFile => '$_appUi/lib/src/widget.dart';

  @override
  void writeTestPackageConfig(PackageConfigFileBuilder config) {
    super.writeTestPackageConfig(
      config.copy()
        ..add(name: 'theme_prego', rootFolder: getFolder(_themePrego))
        ..add(name: 'sesori_app_ui', rootFolder: getFolder(_appUi)),
    );
  }

  @override
  void setUp() {
    rule = AvoidInteractionModeReadsRule(ignoreTestFiles: false);
    super.setUp();
    newFile('$_themePrego/lib/interactions/prego_interaction_scope.dart', r'''
class BuildContext {
  T? dependOnInheritedWidgetOfExactType<T>() => null;
  T? getInheritedWidgetOfExactType<T>() => null;
}

enum PregoInteractionMode { touch, pointer }

class PregoInteractionScope {
  const PregoInteractionScope({required this.mode});

  final PregoInteractionMode mode;

  static PregoInteractionMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PregoInteractionScope>()?.mode ?? PregoInteractionMode.touch;
}
''');
    newFile('$_themePrego/lib/theme/prego_design_system.dart', r'''
class PregoDesignSystem {
  const PregoDesignSystem({required this.isDesktopScale});

  final bool isDesktopScale;

  PregoDesignSystem copyWith({bool? isDesktopScale}) =>
      PregoDesignSystem(isDesktopScale: isDesktopScale ?? this.isDesktopScale);
}
''');
    newFile('$_appUi/lib/src/features/session_detail/composer_presentation_scope.dart', r'''
enum ComposerPresentation { touch, pointer }

bool isPointer(ComposerPresentation presentation) => presentation == ComposerPresentation.pointer;
''');
  }

  void test_reportsEachReadInSharedCode() async {
    final source =
        '''
$_imports
bool scope(BuildContext context) => PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
bool notTouch(BuildContext context) => PregoInteractionScope.of(context) != .touch;
bool lookup(BuildContext context) =>
    context.getInheritedWidgetOfExactType<PregoInteractionScope>()?.mode == PregoInteractionMode.pointer;
bool dependent(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PregoInteractionScope>() != null;
bool scale(PregoDesignSystem prego) => prego.isDesktopScale;
bool composer(ComposerPresentation presentation) => presentation == ComposerPresentation.pointer;
bool shorthand(ComposerPresentation presentation) => presentation == .touch;
bool handedIn(PregoInteractionMode mode) => mode == PregoInteractionMode.touch;
''';
    newFile(_sharedFile, source);

    await assertDiagnosticsInFile(_sharedFile, [
      lint(source.indexOf('PregoInteractionScope.of(context) =='), 'PregoInteractionScope.of(context)'.length),
      lint(source.indexOf('PregoInteractionScope.of(context) !='), 'PregoInteractionScope.of(context)'.length),
      lint(
        source.indexOf('context.getInheritedWidgetOfExactType'),
        'context.getInheritedWidgetOfExactType<PregoInteractionScope>()'.length,
      ),
      lint(
        source.indexOf('context.dependOnInheritedWidgetOfExactType'),
        'context.dependOnInheritedWidgetOfExactType<PregoInteractionScope>()'.length,
      ),
      lint(source.indexOf('isDesktopScale;'), 'isDesktopScale'.length),
      lint(source.indexOf('ComposerPresentation.pointer;'), 'ComposerPresentation.pointer'.length),
      lint(source.indexOf('.touch;\nbool handedIn'), '.touch'.length),
      lint(source.indexOf('PregoInteractionMode.touch;'), 'PregoInteractionMode.touch'.length),
    ]);
  }

  void test_reportsInferredLookup() async {
    final source =
        '''
$_scope
bool inferred(BuildContext context) {
  final PregoInteractionScope? scope = context.dependOnInheritedWidgetOfExactType();
  return scope != null;
}
''';
    newFile(_sharedFile, source);

    await assertDiagnosticsInFile(_sharedFile, [
      lint(
        source.indexOf('context.dependOnInheritedWidgetOfExactType'),
        'context.dependOnInheritedWidgetOfExactType()'.length,
      ),
    ]);
  }

  void test_switchOnScopeReadIsOneFinding() async {
    final source =
        '''
$_scope
double size(BuildContext context) => switch (PregoInteractionScope.of(context)) {
  PregoInteractionMode.touch => 44,
  PregoInteractionMode.pointer => 32,
};

double statement(BuildContext context) {
  switch (PregoInteractionScope.of(context)) {
    case PregoInteractionMode.touch:
      return 44;
    case .pointer:
      return 32;
  }
}

double sizeOf(PregoInteractionMode mode) => switch (mode) {
  PregoInteractionMode.touch => 44,
  .pointer => 32,
};
''';
    newFile(_sharedFile, source);

    await assertDiagnosticsInFile(_sharedFile, [
      lint(source.indexOf('PregoInteractionScope.of(context)'), 'PregoInteractionScope.of(context)'.length),
      lint(source.lastIndexOf('PregoInteractionScope.of(context)'), 'PregoInteractionScope.of(context)'.length),
      lint(source.lastIndexOf('PregoInteractionMode.touch'), 'PregoInteractionMode.touch'.length),
      lint(source.lastIndexOf('.pointer => 32'), '.pointer'.length),
    ]);
  }

  void test_reportsThemePregoComponents() async {
    final path = '$_themePrego/lib/components/button.dart';
    final source =
        '''
$_scope
bool pointer(BuildContext context) => PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
''';
    newFile(path, source);

    await assertDiagnosticsInFile(path, [
      lint(source.indexOf('PregoInteractionScope.of'), 'PregoInteractionScope.of(context)'.length),
    ]);
  }

  void test_markerSuppressesItsRead() async {
    newFile(_sharedFile, '''
$_scope
bool scope(BuildContext context) =>
    // ignore: avoid_interaction_mode_reads, pending: metrics
    PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
''');

    await assertNoDiagnosticsInFile(_sharedFile);
  }

  void test_docCommentReferencesAreFree() async {
    newFile(_sharedFile, '''
$_imports
/// Compact under [PregoInteractionMode.pointer], as [PregoDesignSystem.isDesktopScale] and
/// [ComposerPresentation.pointer] are.
const compact = true;
''');

    await assertNoDiagnosticsInFile(_sharedFile);
  }

  void test_definitionsAndWrappersAreFree() async {
    final wrapper = '$_themePrego/lib/interactions/prego_hover_reveal.dart';
    newFile(wrapper, '''
$_scope
bool reveals(BuildContext context) => PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
''');

    await assertNoDiagnosticsInFile('$_themePrego/lib/interactions/prego_interaction_scope.dart');
    await assertNoDiagnosticsInFile('$_themePrego/lib/theme/prego_design_system.dart');
    await assertNoDiagnosticsInFile('$_appUi/lib/src/features/session_detail/composer_presentation_scope.dart');
    await assertNoDiagnosticsInFile(wrapper);
  }

  void test_shellsAndTestsAreFree() async {
    const reads =
        '''
$_imports
bool scope(BuildContext context) => PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
bool scale(PregoDesignSystem prego) => prego.isDesktopScale;
bool composer(ComposerPresentation presentation) => presentation == ComposerPresentation.pointer;
''';
    final sharedTest = '$_appUi/test/widget_test.dart';
    newFile(sharedTest, reads);

    // The package under test is a shell.
    await assertNoDiagnostics(reads);
    await assertNoDiagnosticsInFile(sharedTest);
  }
}
