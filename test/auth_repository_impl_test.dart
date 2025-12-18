// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:loguruin/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';
import 'package:loguruin/src/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AuthRepositoryImpl', () {
    late FakeAuthDataSource dataSource;
    late AuthRepository repository;

    setUp(() {
      dataSource = FakeAuthDataSource();
      repository = AuthRepositoryImpl(dataSource: dataSource);
    });

    test('logIn caches user and reports valid session', () async {
      final user = await repository.logIn(username: 'alice', password: 'pw');

      expect(user.username, 'alice');
      expect(await repository.hasValidSession(), isTrue);
      expect(await repository.getCurrentUser(), user);
      expect(dataSource.getSavedUserCalls, 0);
    });

    test('getCurrentUser returns null when no session', () async {
      expect(await repository.getCurrentUser(), isNull);
      expect(await repository.hasValidSession(), isFalse);
    });

    test('getCurrentUser clears expired cache', () async {
      dataSource = FakeAuthDataSource(
        issuedAt: DateTime.now().toUtc().subtract(
          kAuthTokenValidity + const Duration(seconds: 1),
        ),
      );
      repository = AuthRepositoryImpl(dataSource: dataSource);
      await repository.logIn(username: 'bob', password: 'pw');

      expect(await repository.getCurrentUser(), isNull);
      expect(dataSource.user, isNull);
    });

    test('getSessionExpiry returns expiry for cached session', () async {
      final issuedAt = DateTime.now().toUtc();
      dataSource = FakeAuthDataSource(issuedAt: issuedAt);
      repository = AuthRepositoryImpl(dataSource: dataSource);
      await repository.logIn(username: 'erin', password: 'pw');

      final expiresAt = await repository.getSessionExpiry();

      expect(expiresAt, issuedAt.add(kAuthTokenValidity));
      expect(dataSource.getSavedUserCalls, 0);
    });

    test('getSessionExpiry clears expired cache', () async {
      dataSource = FakeAuthDataSource(
        issuedAt: DateTime.now().toUtc().subtract(
          kAuthTokenValidity + const Duration(seconds: 1),
        ),
      );
      repository = AuthRepositoryImpl(dataSource: dataSource);
      await repository.logIn(username: 'frank', password: 'pw');

      final expiresAt = await repository.getSessionExpiry();

      expect(expiresAt, isNull);
      expect(dataSource.user, isNull);
    });

    test('refreshSession updates cached tokens', () async {
      await repository.logIn(username: 'carol', password: 'pw');
      final initial = await repository.getCurrentUser();
      expect(initial, isNotNull);

      final refreshed = await repository.refreshSession();

      expect(refreshed.tokens.accessToken, isNot(initial!.tokens.accessToken));
      expect(refreshed.tokens.refreshToken, isNot(initial.tokens.refreshToken));
      expect(
        refreshed.tokens.lastRefreshedAt.isAfter(
          initial.tokens.lastRefreshedAt,
        ),
        isTrue,
      );
      expect(await repository.getCurrentUser(), refreshed);
    });

    test('logOut clears cache and data source', () async {
      await repository.logIn(username: 'dave', password: 'pw');

      await repository.logOut();

      expect(await repository.getCurrentUser(), isNull);
      expect(dataSource.user, isNull);
    });
  });
}

class FakeAuthDataSource implements AuthDataSource {
  FakeAuthDataSource({DateTime? issuedAt})
    : _issuedAt = issuedAt ?? DateTime.now().toUtc();

  final DateTime _issuedAt;
  LoggedInUser? user;
  int getSavedUserCalls = 0;

  @override
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  }) async {
    user = LoggedInUser(
      id: 'id-$username',
      username: username,
      tokens: AuthTokens(
        accessToken: 'access-$username',
        refreshToken: 'refresh-$username',
        lastRefreshedAt: _issuedAt,
      ),
    );
    return user!;
  }

  @override
  Future<LoggedInUser?> getSavedUser() async {
    getSavedUserCalls++;
    return user;
  }

  @override
  Future<LoggedInUser> refreshTokens() async {
    if (user == null) {
      throw const AuthDataSourceException('No cached session');
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
    user = null;
  }
}
