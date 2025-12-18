// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/logged_in_user.dart';

const Duration kAuthTokenValidity = Duration(minutes: 30);
const String _cachedUserKey = 'auth.cachedUser';

class AuthDataSourceException implements Exception {
  const AuthDataSourceException(this.message);

  final String message;

  @override
  String toString() => 'AuthDataSourceException: $message';
}

/// Provides low-level access to authentication session storage.
abstract class AuthDataSource {
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  });

  Future<LoggedInUser?> getSavedUser();

  Future<LoggedInUser> refreshTokens();

  Future<void> logOut();
}

class AuthLocalDataSource implements AuthDataSource {
  AuthLocalDataSource({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  @override
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw const AuthDataSourceException('Invalid credentials');
    }
    final now = DateTime.now().toUtc();
    final user = LoggedInUser(
      id: 'user-$username',
      username: username,
      tokens: AuthTokens(
        accessToken: _issueToken('access', username, now),
        refreshToken: _issueToken('refresh', username, now),
        lastRefreshedAt: now,
      ),
    );
    await _persistUser(user);
    return user;
  }

  @override
  Future<LoggedInUser?> getSavedUser() async {
    final user = await _readUser();
    if (user == null) {
      return null;
    }
    if (_isTokenExpired(user.tokens)) {
      await logOut();
      return null;
    }
    return user;
  }

  @override
  Future<LoggedInUser> refreshTokens() async {
    final user = await _readUser();
    if (user == null) {
      throw const AuthDataSourceException('No cached session');
    }
    if (_isTokenExpired(user.tokens)) {
      await logOut();
      throw const AuthDataSourceException('Session expired');
    }
    final now = DateTime.now().toUtc();
    final updatedUser = user.copyWith(
      tokens: user.tokens.copyWith(
        accessToken: _issueToken('access', user.username, now),
        refreshToken: _issueToken('refresh', user.username, now),
        lastRefreshedAt: now,
      ),
    );
    await _persistUser(updatedUser);
    return updatedUser;
  }

  @override
  Future<void> logOut() async {
    await _sharedPreferences.remove(_cachedUserKey);
  }

  Future<void> _persistUser(LoggedInUser user) async {
    final jsonString = json.encode(user.toJson());
    final success = await _sharedPreferences.setString(
      _cachedUserKey,
      jsonString,
    );
    if (!success) {
      throw const AuthDataSourceException('Failed to persist session');
    }
  }

  Future<LoggedInUser?> _readUser() async {
    final jsonString = _sharedPreferences.getString(_cachedUserKey);
    if (jsonString == null) {
      return null;
    }
    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      return LoggedInUser.fromJson(decoded);
    } on FormatException {
      await logOut();
      return null;
    } on TypeError {
      await logOut();
      return null;
    }
  }

  bool _isTokenExpired(AuthTokens tokens) {
    final expiresAt = tokens.lastRefreshedAt.toUtc().add(kAuthTokenValidity);
    final now = DateTime.now().toUtc();
    return now.isAfter(expiresAt);
  }
}

String _issueToken(String type, String username, DateTime issuedAt) {
  final raw = '$type:$username:${issuedAt.millisecondsSinceEpoch}';
  return base64Url.encode(utf8.encode(raw));
}
