import 'package:flutter/material.dart';

/// A premium, silky-smooth slide-and-fade page transition builder.
/// Used globally across the application for all [MaterialPageRoute] pushes.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Primary entrance curve
    final enterAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Secondary exit (parallax) curve for the departing route
    final exitAnimation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      // Incoming page slides in slightly from the right (6% offset)
      position: Tween<Offset>(
        begin: const Offset(0.06, 0.0),
        end: Offset.zero,
      ).animate(enterAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
          ),
        ),
        child: SlideTransition(
          // Departing page shifts subtly to the left (-3% parallax)
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.03, 0.0),
          ).animate(exitAnimation),
          child: child,
        ),
      ),
    );
  }
}
