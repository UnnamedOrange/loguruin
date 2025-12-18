// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/app/app.dart';
import 'package:loguruin/src/app/splash_page.dart';
import 'package:loguruin/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:loguruin/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';
import 'package:loguruin/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:loguruin/src/features/auth/presentation/pages/login_page.dart';
import 'package:loguruin/src/features/auth/presentation/providers/auth_view_model.dart';
import 'package:loguruin/src/features/home/presentation/pages/main_page.dart';
import 'package:loguruin/src/routes/app_router.dart';
import 'package:loguruin/src/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sharedPreferences;
  late AuthRepository authRepository;
  late AuthViewModel authViewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    authRepository = AuthRepositoryImpl(
      dataSource: AuthLocalDataSource(sharedPreferences: sharedPreferences),
    );
    authViewModel = AuthViewModel(authRepository: authRepository);
  });

  Widget buildRouterApp(
    AppRouter router,
    AuthViewModel viewModel, {
    String initialRoute = AppRoutes.login,
  }) {
    return AppRouterScope(
      appRouter: router,
      child: ChangeNotifierProvider<AuthViewModel>.value(
        value: viewModel,
        child: MaterialApp(
          navigatorKey: router.navigatorKey,
          onGenerateRoute: router.onGenerateRoute,
          onGenerateInitialRoutes: router.onGenerateInitialRoutes,
          initialRoute: initialRoute,
        ),
      ),
    );
  }

  Widget buildLogin(AuthViewModel viewModel) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: viewModel,
      child: const MaterialApp(home: LoginPage()),
    );
  }

  Widget buildMain(AuthViewModel viewModel, {LoggedInUser? initialUser}) {
    return ChangeNotifierProvider<AuthViewModel>.value(
      value: viewModel,
      child: MaterialApp(home: MainPage(initialUser: initialUser)),
    );
  }

  group('AppRouter', () {
    test('maps destinations to initial routes', () {
      final router = AppRouter();

      expect(router.initialRoute(AppDestination.login), AppRoutes.login);
      expect(router.initialRoute(AppDestination.main), AppRoutes.main);
    });

    testWidgets('initial login route keeps single page on stack', (
      tester,
    ) async {
      final router = AppRouter();
      await authViewModel.bootstrap();

      await tester.pumpWidget(
        buildRouterApp(router, authViewModel, initialRoute: AppRoutes.login),
      );

      expect(find.text('Log in'), findsOneWidget);
      expect(router.navigatorKey.currentState?.canPop(), isFalse);
    });

    testWidgets('goToMain replaces stack with main page', (tester) async {
      final router = AppRouter();
      await authViewModel.logIn(username: 'alice', password: 'pw');

      await tester.pumpWidget(
        buildRouterApp(router, authViewModel, initialRoute: AppRoutes.login),
      );

      router.goToMain(user: authViewModel.user);
      await tester.pumpAndSettle();

      expect(find.text('Main Page'), findsOneWidget);
      expect(find.text('Hello, alice'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
    });

    testWidgets('goToLogin replaces stack with login page', (tester) async {
      final router = AppRouter();
      await authViewModel.logIn(username: 'bob', password: 'pw');

      await tester.pumpWidget(
        buildRouterApp(router, authViewModel, initialRoute: AppRoutes.main),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(
        LoguruinApp(sharedPreferences: sharedPreferences),
      );

      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump();

      expect(find.text('Log in'), findsOneWidget);
    });

    testWidgets('navigates to main after successful login', (tester) async {
      await tester.pumpWidget(
        LoguruinApp(sharedPreferences: sharedPreferences),
      );
      await tester.pump();
      final loginContext = tester.element(find.byType(LoginPage));
      final viewModel = Provider.of<AuthViewModel>(loginContext, listen: false);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'user',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.pump();
      expect(viewModel.isBusy, isFalse);
      final loginButton = find.widgetWithText(ElevatedButton, 'Log in');
      expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);
      await tester.tap(find.text('Log in'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(viewModel.status, AuthStatus.authenticated);
      expect(viewModel.errorMessage, isNull);
      expect(sharedPreferences.getString('auth.cachedUser'), isNotNull);
      expect(find.byType(MainPage), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
    });
  });

  group('LoginPage', () {
    testWidgets('logs in through view model when pressing login button', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin(authViewModel));

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
      await tester.pump();
      await tester.pump();

      expect(authViewModel.status, AuthStatus.authenticated);
      expect(authViewModel.user?.username, 'user');
    });

    testWidgets('disables login button when fields are empty', (tester) async {
      await tester.pumpWidget(buildLogin(authViewModel));

      final loginButton = find.widgetWithText(ElevatedButton, 'Log in');

      expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNull);
    });

    testWidgets('shows validation error when password is too short', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin(authViewModel));

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
      expect(authViewModel.user, isNull);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildLogin(authViewModel));

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
      final slowRepository = _CountingAuthRepository(
        delay: const Duration(milliseconds: 200),
      );
      final slowViewModel = AuthViewModel(authRepository: slowRepository);

      await tester.pumpWidget(buildLogin(slowViewModel));

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

      expect(slowRepository.logInCalls, 1);
      expect(slowViewModel.user, isNull);

      await tester.pump(const Duration(milliseconds: 250));

      expect(slowRepository.logInCalls, 1);
      expect(slowViewModel.status, AuthStatus.authenticated);
      expect(slowViewModel.user?.username, 'user');
    });
  });

  group('MainPage', () {
    testWidgets('logs out when pressing logout button', (tester) async {
      await authViewModel.logIn(username: 'user', password: 'pw');

      await tester.pumpWidget(buildMain(authViewModel));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      expect(authViewModel.status, AuthStatus.unauthenticated);
      expect(authViewModel.user, isNull);
    });

    testWidgets('shows fallback user id on settings tab', (tester) async {
      final initialUser = LoggedInUser(
        id: '',
        username: 'Guest',
        tokens: AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          lastRefreshedAt: DateTime.now().toUtc(),
        ),
      );

      await tester.pumpWidget(
        buildMain(authViewModel, initialUser: initialUser),
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

class _CountingAuthRepository implements AuthRepository {
  _CountingAuthRepository({this.delay = const Duration(milliseconds: 1)});

  final Duration delay;
  int logInCalls = 0;
  LoggedInUser? user;

  @override
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  }) async {
    logInCalls++;
    await Future<void>.delayed(delay);
    final now = DateTime.now().toUtc();
    user = LoggedInUser(
      id: 'id-$username',
      username: username,
      tokens: AuthTokens(
        accessToken: 'access-$username',
        refreshToken: 'refresh-$username',
        lastRefreshedAt: now,
      ),
    );
    return user!;
  }

  @override
  Future<LoggedInUser?> getCurrentUser() async => user;

  @override
  Future<DateTime?> getSessionExpiry() async {
    final current = await getCurrentUser();
    if (current == null) {
      return null;
    }
    return current.tokens.lastRefreshedAt.toUtc().add(kAuthTokenValidity);
  }

  @override
  Future<bool> hasValidSession() async => user != null;

  @override
  Future<LoggedInUser> refreshSession() async {
    if (user == null) {
      throw Exception('No cached session');
    }
    final now = DateTime.now().toUtc();
    user = user!.copyWith(
      tokens: user!.tokens.copyWith(
        accessToken: '${user!.tokens.accessToken}-next',
        refreshToken: '${user!.tokens.refreshToken}-next',
        lastRefreshedAt: now,
      ),
    );
    return user!;
  }

  @override
  Future<void> logOut() async {
    user = null;
  }
}
