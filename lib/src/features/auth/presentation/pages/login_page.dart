// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({required this.onLoggedIn, super.key});

  final VoidCallback onLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onLoggedIn,
          child: const Text('Mock Login'),
        ),
      ),
    );
  }
}
