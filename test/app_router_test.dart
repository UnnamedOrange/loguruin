// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/app/app.dart';
import 'package:loguruin/src/app/splash_page.dart';
import 'package:loguruin/src/features/auth/presentation/pages/login_page.dart';
import 'package:loguruin/src/features/home/presentation/pages/main_page.dart';
import 'package:loguruin/src/routes/app_router.dart';
import 'package:loguruin/src/routes/app_routes.dart';

void main() {
  group('AppRouter.resolveDestination', () {
    test('returns login when unauthenticated', () async {
      final router = AppRouter(
        statusResolver: InMemoryAuthStatusResolver(authenticated: false),
      );

      expect(await router.resolveDestination(), AppDestination.login);
    });

    test('returns main when authenticated', () async {
      final router = AppRouter(
        statusResolver: InMemoryAuthStatusResolver(authenticated: true),
      );

      expect(await router.resolveDestination(), AppDestination.main);
    });

    test('maps destinations to initial routes', () {
      final router = AppRouter();

      expect(router.initialRoute(AppDestination.login), AppRoutes.login);
      expect(router.initialRoute(AppDestination.main), AppRoutes.main);
    });
  });

  group('AppRouter navigation', () {
    testWidgets('initial login route keeps single page on stack', (
      tester,
    ) async {
      final router = AppRouter();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: router.navigatorKey,
          onGenerateRoute: router.onGenerateRoute,
          onGenerateInitialRoutes: router.onGenerateInitialRoutes,
          initialRoute: AppRoutes.login,
        ),
      );

      expect(find.text('Log in'), findsOneWidget);
      expect(router.navigatorKey.currentState?.canPop(), isFalse);
    });

    testWidgets('goToMain replaces stack with main page', (tester) async {
      final router = AppRouter();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: router.navigatorKey,
          onGenerateRoute: router.onGenerateRoute,
          onGenerateInitialRoutes: router.onGenerateInitialRoutes,
          initialRoute: AppRoutes.login,
        ),
      );

      expect(find.text('Log in'), findsOneWidget);

      router.goToMain();
      await tester.pumpAndSettle();

      expect(find.text('Main Page'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
    });

    testWidgets('goToLogin replaces stack with login page', (tester) async {
      final router = AppRouter();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: router.navigatorKey,
          onGenerateRoute: router.onGenerateRoute,
          onGenerateInitialRoutes: router.onGenerateInitialRoutes,
          initialRoute: AppRoutes.main,
        ),
      );

      expect(find.text('Main Page'), findsOneWidget);

      router.goToLogin();
      await tester.pumpAndSettle();

      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Main Page'), findsNothing);
    });

    testWidgets('AppRouterScope exposes router from context', (tester) async {
      final router = AppRouter();
      late AppRouter fromContext;

      await tester.pumpWidget(
        AppRouterScope(
          appRouter: router,
          child: Builder(
            builder: (context) {
              fromContext = AppRouterScope.of(context);
              return const Placeholder();
            },
          ),
        ),
      );

      expect(identical(fromContext, router), isTrue);
    });
  });

  group('LoguruinApp', () {
    testWidgets('shows splash then renders login after bootstrap', (
      tester,
    ) async {
      await tester.pumpWidget(const LoguruinApp());

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump();

      expect(find.text('Log in'), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('invokes callback when pressing login button', (tester) async {
      var loggedIn = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            onLoggedIn: () {
              loggedIn = true;
            },
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'user',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.pump();

      final loginButton = find.widgetWithText(ElevatedButton, 'Log in');
      expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);
      await tester.tap(find.text('Log in'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(loggedIn, isTrue);
    });
  });

  group('MainPage', () {
    testWidgets('invokes callback when pressing logout button', (tester) async {
      var logoutRequested = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MainPage(
            onRequireLogin: () {
              logoutRequested = true;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      expect(logoutRequested, isTrue);
    });
  });
}
