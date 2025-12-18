// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter_test/flutter_test.dart';
import 'package:loguruin/src/features/auth/domain/models/logged_in_user.dart';

void main() {
  group('AuthTokens', () {
    final tokens = AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      lastRefreshedAt: DateTime.utc(2024, 1, 1),
    );

    test('copyWith overrides provided fields', () {
      final updated = tokens.copyWith(
        accessToken: 'next-access',
        lastRefreshedAt: DateTime.utc(2024, 1, 2),
      );

      expect(updated.accessToken, 'next-access');
      expect(updated.refreshToken, tokens.refreshToken);
      expect(updated.lastRefreshedAt, DateTime.utc(2024, 1, 2));
    });

    test('serializes and deserializes', () {
      final restored = AuthTokens.fromJson(tokens.toJson());

      expect(restored, tokens);
    });
  });

  group('LoggedInUser', () {
    final user = LoggedInUser(
      id: 'id-1',
      username: 'tester',
      tokens: AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        lastRefreshedAt: DateTime.utc(2024, 1, 1),
      ),
    );

    test('copyWith updates provided fields', () {
      final replacementTokens = AuthTokens(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
        lastRefreshedAt: DateTime.utc(2024, 1, 3),
      );

      final updated = user.copyWith(
        username: 'next',
        tokens: replacementTokens,
      );

      expect(updated.id, user.id);
      expect(updated.username, 'next');
      expect(updated.tokens, replacementTokens);
    });

    test('serializes and deserializes', () {
      final restored = LoggedInUser.fromJson(user.toJson());

      expect(restored, user);
    });
  });
}
