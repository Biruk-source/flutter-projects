import 'package:flutter/material.dart';

PageRouteBuilder customPageRouteBuilder({required Widget page}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // Starts from right
      const end = Offset.zero; // Ends at center
      const curve = Curves.easeOutCubic; // A smooth, fast-out curve

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(
      milliseconds: 600,
    ), // Duration of the animation
  );
}
