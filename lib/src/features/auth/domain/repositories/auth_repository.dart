// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import '../models/logged_in_user.dart';

abstract class AuthRepository {
  Future<LoggedInUser> logIn({
    required String username,
    required String password,
  });

  Future<LoggedInUser?> getCurrentUser();

  Future<DateTime?> getSessionExpiry();

  Future<bool> hasValidSession();

  Future<LoggedInUser> refreshSession();

  Future<void> logOut();
}
