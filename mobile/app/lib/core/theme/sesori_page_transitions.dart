import "package:flutter/material.dart";

class SesoriFadeForwardsPageTransitionsBuilder extends PageTransitionsBuilder {
  const SesoriFadeForwardsPageTransitionsBuilder({this.backgroundColor});

  final Color? backgroundColor;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 800);

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        bool allowSnapshotting,
        Widget? child,
      ) => _delegatedTransition(context, secondaryAnimation, backgroundColor, child);

  static const Curve _transitionCurve = Curves.easeInOutCubicEmphasized;

  static final Animatable<Offset> _secondaryBackwardTranslationTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.25, 0.0),
  ).chain(CurveTween(curve: _transitionCurve));

  static final Animatable<Offset> _secondaryForwardTranslationTween = Tween<Offset>(
    begin: const Offset(-0.25, 0.0),
    end: Offset.zero,
  ).chain(CurveTween(curve: _transitionCurve));

  static final Animatable<double> _fadeInTransition = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).chain(CurveTween(curve: const Interval(0.0, 0.75)));

  static final Animatable<double> _fadeOutTransition = Tween<double>(
    begin: 1.0,
    end: 0.0,
  ).chain(CurveTween(curve: const Interval(0.0, 0.25)));

  static Widget _delegatedTransition(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Color? backgroundColor,
    Widget? child,
  ) {
    return DualTransitionBuilder(
      animation: ReverseAnimation(secondaryAnimation),
      forwardBuilder: (context, animation, child) {
        return ColoredBox(
          color: animation.isAnimating ? backgroundColor ?? Theme.of(context).colorScheme.surface : Colors.transparent,
          child: FadeTransition(
            opacity: _fadeInTransition.animate(animation),
            child: SlideTransition(position: _secondaryForwardTranslationTween.animate(animation), child: child),
          ),
        );
      },
      reverseBuilder: (context, animation, child) {
        return ColoredBox(
          color: animation.isAnimating ? backgroundColor ?? Theme.of(context).colorScheme.surface : Colors.transparent,
          child: FadeTransition(
            opacity: _fadeOutTransition.animate(animation),
            child: SlideTransition(position: _secondaryBackwardTranslationTween.animate(animation), child: child),
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeForwardsPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      backgroundColor: backgroundColor,
      child: child,
    );
  }
}

class _FadeForwardsPageTransition extends StatelessWidget {
  const _FadeForwardsPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.backgroundColor,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Color? backgroundColor;
  final Widget child;

  static final Animatable<Offset> _forwardTranslationTween = Tween<Offset>(
    begin: const Offset(0.25, 0.0),
    end: Offset.zero,
  ).chain(CurveTween(curve: SesoriFadeForwardsPageTransitionsBuilder._transitionCurve));

  static final Animatable<Offset> _backwardTranslationTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.25, 0.0),
  ).chain(CurveTween(curve: SesoriFadeForwardsPageTransitionsBuilder._transitionCurve));

  @override
  Widget build(BuildContext context) {
    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, animation, child) {
        return FadeTransition(
          opacity: SesoriFadeForwardsPageTransitionsBuilder._fadeInTransition.animate(animation),
          child: SlideTransition(position: _forwardTranslationTween.animate(animation), child: child),
        );
      },
      reverseBuilder: (context, animation, child) {
        return FadeTransition(
          opacity: SesoriFadeForwardsPageTransitionsBuilder._fadeOutTransition.animate(animation),
          child: SlideTransition(position: _backwardTranslationTween.animate(animation), child: child),
        );
      },
      child: SesoriFadeForwardsPageTransitionsBuilder._delegatedTransition(
        context,
        secondaryAnimation,
        backgroundColor,
        child,
      ),
    );
  }
}
