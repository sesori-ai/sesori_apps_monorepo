import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// Forbids Flutter spinner widgets outside the Prego activity indicator.
class AvoidFlutterSpinnersRule extends NoSlopRule {
  AvoidFlutterSpinnersRule({required super.ignoreTestFiles})
    : super(
        name: code.lowerCaseName,
        description: 'Forbids direct use of Flutter spinner widgets.',
      );

  static const code = LintCode(
    'avoid_flutter_spinners',
    'Avoid Flutter spinner widgets.',
    correctionMessage: 'Use PregoActivityIndicator instead. Use RefreshIndicator.noSpinner for pull-to-refresh.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addConstructorReference(this, visitor);
    registry.addInstanceCreationExpression(this, visitor);
  }
}

const _spinnerPackages = {
  'CircularProgressIndicator': 'material_ui',
  'RefreshProgressIndicator': 'material_ui',
  'CupertinoActivityIndicator': 'cupertino_ui',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidFlutterSpinnersRule rule;

  @override
  void visitConstructorReference(ConstructorReference node) {
    if (rule.isCurrentFileExcluded) return;
    _checkConstructor(node.constructorName);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    _checkConstructor(node.constructorName);
  }

  void _checkConstructor(ConstructorName constructorName) {
    final typeName = constructorName.type.name.lexeme;
    final libraryIdentifier = constructorName.element?.library.identifier;
    if (libraryIdentifier == null) return;

    final spinnerPackage = _spinnerPackages[typeName];
    if (spinnerPackage != null && _isFromPackage(libraryIdentifier, spinnerPackage)) {
      rule.reportAtNode(constructorName);
      return;
    }

    if (typeName == 'RefreshIndicator' &&
        constructorName.name?.name != 'noSpinner' &&
        _isFromPackage(libraryIdentifier, 'material_ui')) {
      rule.reportAtNode(constructorName);
    }
  }

  bool _isFromPackage(String libraryIdentifier, String packageName) =>
      libraryIdentifier.startsWith('package:$packageName/');
}
