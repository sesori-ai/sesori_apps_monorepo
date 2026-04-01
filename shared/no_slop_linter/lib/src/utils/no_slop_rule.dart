import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';

abstract class NoSlopRule extends AnalysisRule {
  NoSlopRule({required super.name, required super.description, super.state});

  RuleContext? _context;

  bool get isCurrentFileExcluded {
    final currentPath = _context?.currentUnit?.file.path;
    if (currentPath == null) return false;
    if (currentPath.endsWith('_test.dart')) return true;
    final libraryElement = _context?.libraryElement;
    if (libraryElement == null) return false;
    final isAnalyzed = libraryElement.session.analysisContext.contextRoot
        .isAnalyzed(currentPath);
    return isAnalyzed == false;
  }

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    _context = context;
    registerRuleProcessors(registry, context);
  }

  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  );
}

abstract class NoSlopMultiRule extends MultiAnalysisRule {
  NoSlopMultiRule({
    required super.name,
    required super.description,
    super.state,
  });

  RuleContext? _context;

  bool get isCurrentFileExcluded {
    final currentPath = _context?.currentUnit?.file.path;
    if (currentPath == null) return false;
    if (currentPath.endsWith('_test.dart')) return true;
    final libraryElement = _context?.libraryElement;
    if (libraryElement == null) return false;
    final isAnalyzed = libraryElement.session.analysisContext.contextRoot
        .isAnalyzed(currentPath);
    return isAnalyzed == false;
  }

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    _context = context;
    registerRuleProcessors(registry, context);
  }

  void registerRuleProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  );
}
