// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/datasources/auth_local_data_source.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/models/logged_in_user.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/providers/auth_view_model.dart';
import '../routes/app_router.dart';
import 'splash_page.dart';

class LoguruinApp extends StatefulWidget {
  const LoguruinApp({required this.sharedPreferences, super.key});

  final SharedPreferences sharedPreferences;

  @override
  State<LoguruinApp> createState() => _LoguruinAppState();
}

class _LoguruinAppState extends State<LoguruinApp> {
  late final AppRouter _appRouter;
  late final AuthRepository _authRepository;
  late final AuthViewModel _authViewModel;
  AppDestination _destination = AppDestination.login;
  AppDestination _currentDestination = AppDestination.login;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();
    _authRepository = AuthRepositoryImpl(
      dataSource: AuthLocalDataSource(
        sharedPreferences: widget.sharedPreferences,
      ),
    );
    _authViewModel = AuthViewModel(authRepository: _authRepository)
      ..addListener(_handleAuthStateChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _authViewModel.bootstrap();
    final destination = _authViewModel.isAuthenticated
        ? AppDestination.main
        : AppDestination.login;
    if (!mounted) {
      return;
    }
    setState(() {
      _destination = destination;
      _currentDestination = destination;
      _bootstrapped = true;
    });
  }

  void _handleAuthStateChanged() {
    if (!_bootstrapped) {
      return;
    }
    switch (_authViewModel.status) {
      case AuthStatus.authenticated:
        final user = _authViewModel.user;
        if (user != null && _currentDestination != AppDestination.main) {
          _navigateTo(AppDestination.main, user: user);
        }
        break;
      case AuthStatus.unauthenticated:
        if (_currentDestination != AppDestination.login) {
          _navigateTo(AppDestination.login);
        }
        break;
      default:
        break;
    }
  }

  void _navigateTo(AppDestination destination, {LoggedInUser? user}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = _appRouter.navigatorKey.currentState;
      if (navigator == null) {
        _navigateTo(destination, user: user);
        return;
      }
      switch (destination) {
        case AppDestination.main:
          if (user == null) {
            return;
          }
          _appRouter.goToMain(user: user);
          break;
        case AppDestination.login:
          _appRouter.goToLogin();
          break;
      }
      _currentDestination = destination;
    });
  }

  @override
  void dispose() {
    _authViewModel.removeListener(_handleAuthStateChanged);
    _authViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _bootstrapped
        ? MultiProvider(
            providers: [
              Provider<AuthRepository>.value(value: _authRepository),
              ChangeNotifierProvider<AuthViewModel>.value(
                value: _authViewModel,
              ),
            ],
            child: MaterialApp(
              navigatorKey: _appRouter.navigatorKey,
              onGenerateRoute: _appRouter.onGenerateRoute,
              onGenerateInitialRoutes: _appRouter.onGenerateInitialRoutes,
              initialRoute: _appRouter.initialRoute(_destination),
            ),
          )
        : const MaterialApp(home: SplashPage());
    return AppRouterScope(appRouter: _appRouter, child: child);
  }
}
