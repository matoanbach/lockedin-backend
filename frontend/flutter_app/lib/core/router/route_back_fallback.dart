import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouteBackFallback extends StatelessWidget {
  const RouteBackFallback({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  final String fallbackLocation;
  final Widget child;

  static void navigate(BuildContext context, String fallbackLocation) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && context.mounted) {
          context.go(fallbackLocation);
        }
      },
      child: child,
    );
  }
}
