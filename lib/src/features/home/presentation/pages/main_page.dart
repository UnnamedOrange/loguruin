// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    required this.onRequireLogin,
    this.username = 'User',
    this.userId,
    super.key,
  });

  final VoidCallback onRequireLogin;
  final String username;
  final String? userId;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Main Page' : 'Settings'),
        actions: [
          IconButton(
            onPressed: widget.onRequireLogin,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          _HomeView(username: widget.username),
          _SettingsView(
            username: widget.username,
            userId: widget.userId,
            onLogOut: widget.onRequireLogin,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Hello, $username',
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.username,
    required this.onLogOut,
    this.userId,
  });

  final String username;
  final String? userId;
  final VoidCallback onLogOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedUserId = userId?.isNotEmpty == true
        ? userId!
        : 'Unknown user';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(username),
            subtitle: Text(resolvedUserId),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onLogOut,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
