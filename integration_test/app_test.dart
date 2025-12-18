// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loguruin/main.dart' as app;
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';
import 'package:loguruin/src/features/auth/presentation/pages/login_page.dart';
import 'package:loguruin/src/features/auth/presentation/providers/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _launchApp(WidgetTester tester) async {
  await app.main();
  await tester.pumpAndSettle();
}

Future<void> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final finder = find.text(text);
  final end = DateTime.now().toUtc().add(timeout);
  while (DateTime.now().toUtc().isBefore(end)) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String Function()? reasonBuilder,
}) async {
  final end = DateTime.now().toUtc().add(timeout);
  while (DateTime.now().toUtc().isBefore(end)) {
    await tester.pump();
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: reasonBuilder?.call());
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('user can log in then log out through UI', (tester) async {
    await _launchApp(tester);

    await _waitForText(tester, 'Log in');
    final loginContext = tester.element(find.byType(LoginPage));
    final authViewModel = Provider.of<AuthViewModel>(
      loginContext,
      listen: false,
    );
    final statusChanges = <AuthStatus>[];
    authViewModel.addListener(() {
      statusChanges.add(authViewModel.status);
    });

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Username'),
      'e2e-user',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Username'))
          .controller
          ?.text,
      'e2e-user',
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Password'))
          .controller
          ?.text,
      'password',
    );
    final loginButton = find.widgetWithText(ElevatedButton, 'Log in');
    expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _waitForCondition(
      tester,
      () =>
          authViewModel.status == AuthStatus.authenticated ||
          authViewModel.status == AuthStatus.unauthenticated,
      reasonBuilder: () =>
          'status: ${authViewModel.status}, changes: $statusChanges, '
          'error: ${authViewModel.errorMessage}',
    );
    expect(
      statusChanges.contains(AuthStatus.authenticating),
      isTrue,
      reason: 'statusChanges: $statusChanges',
    );
    expect(
      authViewModel.status,
      AuthStatus.authenticated,
      reason: authViewModel.errorMessage,
    );
    await _waitForText(tester, 'Hello, e2e-user');

    expect(find.text('Log in'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth.cachedUser'), isNotNull);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Log in');

    expect(find.text('Log in'), findsOneWidget);
    expect(prefs.getString('auth.cachedUser'), isNull);
  });

  testWidgets('opens main page when a cached session exists', (tester) async {
    final user = LoggedInUser(
      id: 'cached-id',
      username: 'cached-user',
      tokens: AuthTokens(
        accessToken: 'cached-access',
        refreshToken: 'cached-refresh',
        lastRefreshedAt: DateTime.now().toUtc(),
      ),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth.cachedUser': json.encode(user.toJson()),
    });

    await _launchApp(tester);
    await tester.pumpAndSettle();
    await _waitForText(tester, 'Hello, cached-user');

    expect(find.text('Log in'), findsNothing);
  });
}
