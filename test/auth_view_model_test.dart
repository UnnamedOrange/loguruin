// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';
import 'package:loguruin/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:loguruin/src/features/auth/presentation/providers/auth_view_model.dart';

void main() {
  group('AuthViewModel', () {
    late FakeAuthRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = FakeAuthRepository();
      viewModel = AuthViewModel(authRepository: repository);
    });

    test('bootstrap loads cached user', () async {
      repository.user = _buildUser('alice');

      await viewModel.bootstrap();

      expect(viewModel.status, AuthStatus.authenticated);
      expect(viewModel.user, repository.user);
      expect(viewModel.errorMessage, isNull);
    });

    test('bootstrap returns unauthenticated when no cache', () async {
      await viewModel.bootstrap();

      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.user, isNull);
    });

    test('logIn updates authenticated state', () async {
      final success = await viewModel.logIn(username: 'bob', password: 'pw');

      expect(success, isTrue);
      expect(viewModel.status, AuthStatus.authenticated);
      expect(viewModel.user?.username, 'bob');
      expect(viewModel.errorMessage, isNull);
    });

    test('logIn surfaces failures and clears user', () async {
      repository.throwOnLogIn = true;

      final success = await viewModel.logIn(username: 'bob', password: 'pw');

      expect(success, isFalse);
      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.user, isNull);
      expect(viewModel.errorMessage, isNotNull);
    });

    test('refreshSession updates tokens and keeps authenticated', () async {
      await viewModel.logIn(username: 'carol', password: 'pw');
      final initialTokens = viewModel.user!.tokens;

      final success = await viewModel.refreshSession();

      expect(success, isTrue);
      expect(viewModel.status, AuthStatus.authenticated);
      expect(
        viewModel.user?.tokens.accessToken,
        isNot(initialTokens.accessToken),
      );
      expect(viewModel.errorMessage, isNull);
    });

    test('refreshSession logs out when refresh fails', () async {
      repository.user = _buildUser('dave');
      repository.throwOnRefresh = true;

      final success = await viewModel.refreshSession();

      expect(success, isFalse);
      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.user, isNull);
      expect(repository.logOutCalled, isTrue);
    });

    test('logOut clears user and sets unauthenticated state', () async {
      await viewModel.logIn(username: 'eve', password: 'pw');

      await viewModel.logOut();

      expect(viewModel.status, AuthStatus.unauthenticated);
      expect(viewModel.user, isNull);
      expect(repository.logOutCalled, isTrue);
    });
  });
}

LoggedInUser _buildUser(String username) {
  return LoggedInUser(
    id: 'id-$username',
    username: username,
    tokens: AuthTokens(
      accessToken: 'access-$username',
      refreshToken: 'refresh-$username',
      lastRefreshedAt: DateTime.now().toUtc(),
    ),
  );
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});

  LoggedInUser? user;
  bool throwOnLogIn = false;
  bool throwOnRefresh = false;
  bool logOutCalled = false;

  @override
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  }) async {
    if (throwOnLogIn) {
      throw Exception('Log in failed');
    }
    user = _buildUser(username);
    return user!;
  }

  @override
  Future<LoggedInUser?> getCurrentUser() async => user;

  @override
  Future<bool> hasValidSession() async => user != null;

  @override
  Future<LoggedInUser> refreshSession() async {
    if (throwOnRefresh) {
      throw Exception('Refresh failed');
    }
    if (user == null) {
      throw Exception('No cached session');
    }
    user = user!.copyWith(
      tokens: user!.tokens.copyWith(
        accessToken: '${user!.tokens.accessToken}-next',
        refreshToken: '${user!.tokens.refreshToken}-next',
        lastRefreshedAt: DateTime.now().toUtc(),
      ),
    );
    return user!;
  }

  @override
  Future<void> logOut() async {
    logOutCalled = true;
    user = null;
  }
}
