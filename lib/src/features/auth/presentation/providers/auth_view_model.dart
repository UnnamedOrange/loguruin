// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/foundation.dart';

import '../../domain/models/logged_in_user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
  refreshing,
}

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;
  AuthStatus _status = AuthStatus.initializing;
  LoggedInUser? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  LoggedInUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isBusy =>
      _status == AuthStatus.authenticating || _status == AuthStatus.refreshing;

  Future<void> bootstrap() async {
    _setState(status: AuthStatus.refreshing, clearErrorMessage: true);
    try {
      final current = await _authRepository.getCurrentUser();
      if (current == null) {
        _setState(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          clearErrorMessage: true,
        );
        return;
      }
      _setState(
        status: AuthStatus.authenticated,
        user: current,
        clearErrorMessage: true,
      );
    } catch (error) {
      _setState(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<bool> logIn({
    required String username,
    required String password,
  }) async {
    _setState(status: AuthStatus.authenticating, clearErrorMessage: true);
    try {
      final user = await _authRepository.logIn(
        username: username,
        password: password,
      );
      _setState(
        status: AuthStatus.authenticated,
        user: user,
        clearErrorMessage: true,
      );
      return true;
    } catch (error) {
      _setState(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> refreshSession() async {
    _setState(status: AuthStatus.refreshing, clearErrorMessage: true);
    try {
      final user = await _authRepository.refreshSession();
      _setState(
        status: AuthStatus.authenticated,
        user: user,
        clearErrorMessage: true,
      );
      return true;
    } catch (error) {
      await _authRepository.logOut();
      _setState(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> logOut() async {
    await _authRepository.logOut();
    _setState(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearErrorMessage: true,
    );
  }

  void _setState({
    required AuthStatus status,
    LoggedInUser? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    final nextUser = clearUser ? null : (user ?? _user);
    final nextErrorMessage = clearErrorMessage
        ? null
        : (errorMessage ?? _errorMessage);

    if (_status == status &&
        _user == nextUser &&
        _errorMessage == nextErrorMessage) {
      return;
    }

    _status = status;
    _user = nextUser;
    _errorMessage = nextErrorMessage;
    notifyListeners();
  }
}
