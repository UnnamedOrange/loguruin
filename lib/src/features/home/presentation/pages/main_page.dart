// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  const MainPage({required this.onRequireLogin, super.key});

  final VoidCallback onRequireLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main'),
        actions: [
          IconButton(onPressed: onRequireLogin, icon: const Icon(Icons.logout)),
        ],
      ),
      body: const Center(child: Text('Main Page')),
    );
  }
}
