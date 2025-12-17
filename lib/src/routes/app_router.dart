// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/main_page.dart';
import 'app_routes.dart';

enum AppDestination { login, main }

abstract class AuthStatusResolver {
  Future<bool> hasValidSession();
}

class InMemoryAuthStatusResolver implements AuthStatusResolver {
  InMemoryAuthStatusResolver({bool authenticated = false})
    : _authenticated = authenticated;

  bool _authenticated;

  @override
  Future<bool> hasValidSession() async => _authenticated;

  Future<void> setAuthenticated(bool value) async {
    _authenticated = value;
  }
}

class AppRouter {
  AppRouter({AuthStatusResolver? statusResolver})
    : authStatusResolver = statusResolver ?? InMemoryAuthStatusResolver();

  final AuthStatusResolver authStatusResolver;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<AppDestination> resolveDestination() async {
    final hasSession = await authStatusResolver.hasValidSession();
    return hasSession ? AppDestination.main : AppDestination.login;
  }

  String initialRoute(AppDestination destination) {
    return destination == AppDestination.main
        ? AppRoutes.main
        : AppRoutes.login;
  }

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (_) => LoginPage(onLoggedIn: goToMain),
        );
      case AppRoutes.main:
        return MaterialPageRoute<void>(
          builder: (_) => MainPage(onRequireLogin: goToLogin),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => LoginPage(onLoggedIn: goToMain),
        );
    }
  }

  void goToMain() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.main, (_) => false);
  }

  void goToLogin() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}

class AppRouterScope extends InheritedWidget {
  const AppRouterScope({
    required this.appRouter,
    required super.child,
    super.key,
  });

  final AppRouter appRouter;

  static AppRouter of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppRouterScope>();
    assert(scope != null, 'AppRouterScope not found in context');
    return scope!.appRouter;
  }

  @override
  bool updateShouldNotify(covariant AppRouterScope oldWidget) => false;
}
