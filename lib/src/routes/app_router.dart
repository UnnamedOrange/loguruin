// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

import '../features/auth/domain/models/logged_in_user.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/main_page.dart';
import 'app_routes.dart';

enum AppDestination { login, main }

class AppRouter {
  AppRouter();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String initialRoute(AppDestination destination) {
    return destination == AppDestination.main
        ? AppRoutes.main
        : AppRoutes.login;
  }

  List<Route<dynamic>> onGenerateInitialRoutes(String initialRouteName) {
    return <Route<dynamic>>[_buildRoute(RouteSettings(name: initialRouteName))];
  }

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return _buildRoute(settings);
  }

  void goToMain({LoggedInUser? user}) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(
      AppRoutes.main,
      (_) => false,
      arguments: user,
    );
  }

  void goToLogin() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Route<dynamic> _buildRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.main:
        return MaterialPageRoute<void>(
          builder: (_) =>
              MainPage(initialUser: settings.arguments as LoggedInUser?),
        );
      case AppRoutes.login:
      case '/':
      default:
        return MaterialPageRoute<void>(builder: (_) => const LoginPage());
    }
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
