// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sharedPreferences;
  late AuthLocalDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    dataSource = AuthLocalDataSource(sharedPreferences: sharedPreferences);
  });

  group('logIn', () {
    test('persists and returns user', () async {
      final user = await dataSource.logIn(username: 'alice', password: 'pw');

      expect(user.username, 'alice');

      final cached = await dataSource.getSavedUser();

      expect(cached, user);
    });

    test('throws on empty credentials', () async {
      expect(
        dataSource.logIn(username: '', password: ''),
        throwsA(isA<AuthDataSourceException>()),
      );
    });
  });

  group('getSavedUser', () {
    test('returns null when no session exists', () async {
      expect(await dataSource.getSavedUser(), isNull);
    });

    test('returns null and clears expired session', () async {
      final expiredUser = LoggedInUser(
        id: 'id',
        username: 'user',
        tokens: AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          lastRefreshedAt: DateTime.now().toUtc().subtract(
            kAuthTokenValidity + const Duration(seconds: 1),
          ),
        ),
      );
      await sharedPreferences.setString(
        'auth.cachedUser',
        json.encode(expiredUser.toJson()),
      );

      final cached = await dataSource.getSavedUser();

      expect(cached, isNull);
      expect(sharedPreferences.getString('auth.cachedUser'), isNull);
    });

    test('clears malformed cached data', () async {
      await sharedPreferences.setString('auth.cachedUser', 'not json');

      final cached = await dataSource.getSavedUser();

      expect(cached, isNull);
      expect(sharedPreferences.getString('auth.cachedUser'), isNull);
    });
  });

  group('refreshTokens', () {
    test('refreshes tokens for valid session', () async {
      final initial = await dataSource.logIn(username: 'alice', password: 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 2));

      final refreshed = await dataSource.refreshTokens();

      expect(refreshed.tokens.accessToken, isNot(initial.tokens.accessToken));
      expect(refreshed.tokens.refreshToken, isNot(initial.tokens.refreshToken));
      expect(
        refreshed.tokens.lastRefreshedAt.isAfter(
          initial.tokens.lastRefreshedAt,
        ),
        isTrue,
      );

      final cached = await dataSource.getSavedUser();

      expect(cached, refreshed);
    });

    test('throws and clears when expired', () async {
      final expiredUser = LoggedInUser(
        id: 'id',
        username: 'user',
        tokens: AuthTokens(
          accessToken: 'a',
          refreshToken: 'r',
          lastRefreshedAt: DateTime.now().toUtc().subtract(
            kAuthTokenValidity + const Duration(seconds: 1),
          ),
        ),
      );
      await sharedPreferences.setString(
        'auth.cachedUser',
        json.encode(expiredUser.toJson()),
      );

      expect(
        dataSource.refreshTokens(),
        throwsA(isA<AuthDataSourceException>()),
      );
      expect(await dataSource.getSavedUser(), isNull);
    });

    test('throws when no cached session', () async {
      expect(
        dataSource.refreshTokens(),
        throwsA(isA<AuthDataSourceException>()),
      );
    });
  });

  group('logOut', () {
    test('clears cached session', () async {
      await dataSource.logIn(username: 'alice', password: 'pw');

      await dataSource.logOut();

      expect(await dataSource.getSavedUser(), isNull);
    });
  });
}
