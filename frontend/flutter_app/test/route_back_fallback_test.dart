import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lockdin_app/core/router/app_router.dart';
import 'package:lockdin_app/core/router/route_back_fallback.dart';

void main() {
  testWidgets('button falls back when there is no route to pop', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.tap(find.text('Back from rules'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard test target'), findsOneWidget);
  });

  testWidgets('system back falls back when there is no route to pop', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Dashboard test target'), findsOneWidget);
  });

  testWidgets('button pops when dashboard is beneath rules', (tester) async {
    final router = _router(initialLocation: AppRoutes.dashboard);
    addTearDown(router.dispose);

    await _pumpApp(tester, router);
    router.push(AppRoutes.lockdownRules);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back from rules'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard test target'), findsOneWidget);
  });
}

GoRouter _router({String initialLocation = AppRoutes.lockdownRules}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, _) => const Scaffold(body: Text('Dashboard test target')),
      ),
      GoRoute(
        path: AppRoutes.lockdownRules,
        builder: (_, _) => RouteBackFallback(
          fallbackLocation: AppRoutes.dashboard,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      RouteBackFallback.navigate(context, AppRoutes.dashboard),
                  child: const Text('Back from rules'),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _pumpApp(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}
