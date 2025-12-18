// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/models/logged_in_user.dart';
import '../../../auth/presentation/providers/auth_view_model.dart';

class MainPage extends StatefulWidget {
  const MainPage({this.initialUser, super.key});

  final LoggedInUser? initialUser;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _sessionValidated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSessionValid());
  }

  Future<void> _ensureSessionValid() async {
    if (_sessionValidated || !mounted) {
      return;
    }
    _sessionValidated = true;
    final authViewModel = context.read<AuthViewModel>();
    if (authViewModel.status == AuthStatus.authenticated) {
      await authViewModel.refreshSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final user = authViewModel.user ?? widget.initialUser;
    final username = user?.username ?? 'User';
    final userId = user?.id ?? 'Unknown user';
    final isBusy = authViewModel.isBusy;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Main Page' : 'Settings'),
        actions: [
          IconButton(
            onPressed: isBusy ? null : () => authViewModel.logOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: <Widget>[
          _HomeView(username: username),
          _SettingsView(
            username: username,
            userId: userId,
            onLogOut: isBusy ? null : () => authViewModel.logOut(),
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
    required this.userId,
    required this.onLogOut,
  });

  final String username;
  final String userId;
  final VoidCallback? onLogOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(username),
            subtitle: Text(userId.isNotEmpty ? userId : 'Unknown user'),
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
