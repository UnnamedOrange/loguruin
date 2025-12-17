// Copyright (c) UnnamedOrange. Licensed under the MIT License.
// See the LICENSE file in the repository root for full License text.

import 'package:flutter/foundation.dart';

/// Represents an access/refresh token pair with last refresh time.
@immutable
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.lastRefreshedAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime lastRefreshedAt;

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? lastRefreshedAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
    );
  }

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      lastRefreshedAt: DateTime.parse(json['lastRefreshedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'lastRefreshedAt': lastRefreshedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.lastRefreshedAt == lastRefreshedAt;
  }

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, lastRefreshedAt);
}

/// Represents an authenticated user session.
@immutable
class LoggedInUser {
  const LoggedInUser({
    required this.id,
    required this.username,
    required this.tokens,
  });

  final String id;
  final String username;
  final AuthTokens tokens;

  LoggedInUser copyWith({String? id, String? username, AuthTokens? tokens}) {
    return LoggedInUser(
      id: id ?? this.id,
      username: username ?? this.username,
      tokens: tokens ?? this.tokens,
    );
  }

  factory LoggedInUser.fromJson(Map<String, dynamic> json) {
    return LoggedInUser(
      id: json['id'] as String,
      username: json['username'] as String,
      tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'tokens': tokens.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LoggedInUser &&
        other.id == id &&
        other.username == username &&
        other.tokens == tokens;
  }

  @override
  int get hashCode => Object.hash(id, username, tokens);
}
