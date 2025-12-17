// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

import '../routes/app_router.dart';
import 'splash_page.dart';

class LoguruinApp extends StatefulWidget {
  const LoguruinApp({super.key});

  @override
  State<LoguruinApp> createState() => _LoguruinAppState();
}

class _LoguruinAppState extends State<LoguruinApp> {
  late final AppRouter _appRouter;
  AppDestination _destination = AppDestination.login;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final destination = await _appRouter.resolveDestination();
    if (!mounted) {
      return;
    }
    setState(() {
      _destination = destination;
      _bootstrapped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = _bootstrapped
        ? MaterialApp(
            navigatorKey: _appRouter.navigatorKey,
            onGenerateRoute: _appRouter.onGenerateRoute,
            initialRoute: _appRouter.initialRoute(_destination),
          )
        : const MaterialApp(
            home: SplashPage(),
          );
    return AppRouterScope(
      appRouter: _appRouter,
      child: child,
    );
  }
}
