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

    testWidgets('goToMain passes username to main page greeting', (
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

      router.goToMain(username: 'alice');
      await tester.pumpAndSettle();

      expect(find.text('Hello, alice'), findsOneWidget);
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
      String? loggedInUsername;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            onLoggedIn: (username) => loggedInUsername = username,
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

      expect(loggedInUsername, 'user');
    });

    testWidgets('disables login button when fields are empty', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginPage(onLoggedIn: (_) {})));

      final loginButton = find.widgetWithText(ElevatedButton, 'Log in');

      expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNull);
    });

    testWidgets('shows validation error when password is too short', (
      tester,
    ) async {
      var didLogIn = false;

      await tester.pumpWidget(
        MaterialApp(home: LoginPage(onLoggedIn: (_) => didLogIn = true)),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'user',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        '123',
      );
      await tester.tap(find.text('Log in'));
      await tester.pump();

      final formState = tester.state<FormState>(find.byType(Form));
      expect(formState.validate(), isFalse);
      await tester.pump();

      final passwordFieldState = tester.state<FormFieldState<String>>(
        find.widgetWithText(TextFormField, 'Password'),
      );
      expect(
        passwordFieldState.errorText,
        'Password must be at least 6 characters',
      );
      expect(didLogIn, isFalse);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(MaterialApp(home: LoginPage(onLoggedIn: (_) {})));

      final passwordField = find.descendant(
        of: find.widgetWithText(TextFormField, 'Password'),
        matching: find.byType(TextField),
      );

      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
    });

    testWidgets('disables form while submitting', (tester) async {
      String? loggedInUsername;
      var submitCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            onLoggedIn: (username) {
              submitCount++;
              loggedInUsername = username;
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
      await tester.tap(find.text('Log in'));
      await tester.pump();
      await tester.tap(find.text('Log in'));
      await tester.pump();

      expect(submitCount, 0);
      expect(loggedInUsername, isNull);

      await tester.pump(const Duration(milliseconds: 200));
      expect(submitCount, 0);
      await tester.pump(const Duration(milliseconds: 200));

      expect(submitCount, 1);
      expect(loggedInUsername, 'user');
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

    testWidgets('shows fallback user id on settings tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainPage(onRequireLogin: () {}, username: 'Guest'),
        ),
      );

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final appBarTitle = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      );
      expect(appBarTitle, findsOneWidget);
      expect(find.text('Guest'), findsWidgets);
      expect(find.text('Unknown user'), findsOneWidget);
    });
  });
}
