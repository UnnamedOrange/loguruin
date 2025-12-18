// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import '../../domain/models/logged_in_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthDataSource dataSource})
    : _dataSource = dataSource;

  final AuthDataSource _dataSource;
  LoggedInUser? _cachedUser;

  @override
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  }) async {
    final user = await _dataSource.logIn(
      username: username,
      password: password,
    );
    _cachedUser = user;
    return user;
  }

  @override
  Future<LoggedInUser?> getCurrentUser() async {
    final cached = _cachedUser;
    if (cached != null && !_isTokenExpired(cached.tokens)) {
      return cached;
    }

    final user = await _dataSource.getSavedUser();
    if (user == null) {
      _cachedUser = null;
      return null;
    }
    if (_isTokenExpired(user.tokens)) {
      await logOut();
      return null;
    }
    _cachedUser = user;
    return user;
  }

  @override
  Future<bool> hasValidSession() async {
    return await getCurrentUser() != null;
  }

  @override
  Future<LoggedInUser> refreshSession() async {
    try {
      final user = await _dataSource.refreshTokens();
      _cachedUser = user;
      return user;
    } on AuthDataSourceException {
      _cachedUser = null;
      rethrow;
    }
  }

  @override
  Future<void> logOut() async {
    _cachedUser = null;
    await _dataSource.logOut();
  }

  bool _isTokenExpired(AuthTokens tokens) {
    final expiresAt = tokens.lastRefreshedAt.toUtc().add(kAuthTokenValidity);
    return DateTime.now().toUtc().isAfter(expiresAt);
  }
}
