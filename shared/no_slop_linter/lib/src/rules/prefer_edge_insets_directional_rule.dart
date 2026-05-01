import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils/no_slop_rule.dart';

/// A lint rule that enforces EdgeInsetsDirectional over EdgeInsets.
///
/// Using EdgeInsetsDirectional ensures proper RTL (right-to-left) language support
/// by using start/end instead of left/right.
///
/// Examples that trigger this rule:
/// - `EdgeInsets.only(left: 8)` - uses left/right
/// - `EdgeInsets.fromLTRB(8, 0, 8, 0)` - uses left/right
///
/// Valid examples:
/// - `EdgeInsetsDirectional.only(start: 8)`
/// - `EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0)`
/// - `EdgeInsets.all(8)` - symmetric, no RTL issue
/// - `EdgeInsets.symmetric(horizontal: 8)` - symmetric, no RTL issue
/// - When parameter type is specifically `EdgeInsets` (not `EdgeInsetsGeometry`)
class PreferEdgeInsetsDirectionalRule extends NoSlopRule {
  PreferEdgeInsetsDirectionalRule({required super.ignoreTestFiles}) : super(name: code.lowerCaseName, description: 'Enforces EdgeInsetsDirectional for RTL support.');

  static const code = LintCode(
    'prefer_edge_insets_directional',
    'Use EdgeInsetsDirectional for RTL support.',
    correctionMessage: 'Replace EdgeInsets.only/fromLTRB with EdgeInsetsDirectional equivalents.',
  );

  static const _problematicConstructors = {'only', 'fromLTRB'};

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerRuleProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final PreferEdgeInsetsDirectionalRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (rule.isCurrentFileExcluded) return;
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName != 'EdgeInsets') return;

    final constructorName = node.constructorName.name?.name;
    if (constructorName == null ||
        !PreferEdgeInsetsDirectionalRule._problematicConstructors.contains(constructorName)) {
      return;
    }

    if (_isPassedToEdgeInsetsParameter(node)) {
      return;
    }

    rule.reportAtNode(node);
  }

  bool _isPassedToEdgeInsetsParameter(InstanceCreationExpression node) {
    final parent = node.parent;

    if (parent is NamedExpression) {
      final element = parent.element;
      if (element != null) {
        final typeName = element.type.toString().replaceAll('?', '');
        return typeName == 'EdgeInsets';
      }
    }

    return false;
  }
}
