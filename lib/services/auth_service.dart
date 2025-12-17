import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_profile.dart';
import '../core/constants/supabase_config.dart';

/// Supported OAuth providers
enum SocialProvider {
  google,
  apple,
  facebook,
}

/// Authentication service for handling user auth operations
class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );

    // Profile is auto-created via database trigger
    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with OAuth provider (Google, Apple, Facebook)
  Future<bool> signInWithProvider(SocialProvider provider) async {
    final OAuthProvider oauthProvider;
    
    switch (provider) {
      case SocialProvider.google:
        oauthProvider = OAuthProvider.google;
        break;
      case SocialProvider.apple:
        oauthProvider = OAuthProvider.apple;
        break;
      case SocialProvider.facebook:
        oauthProvider = OAuthProvider.facebook;
        break;
    }

    final response = await _client.auth.signInWithOAuth(
      oauthProvider,
      redirectTo: kIsWeb ? null : 'com.shizlist.shizlist://login-callback',
      authScreenLaunchMode: LaunchMode.platformDefault,
    );

    return response;
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from(SupabaseConfig.usersTable)
        .select()
        .eq('uid', userId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  /// Update user profile
  Future<UserProfile> updateUserProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final response = await _client
        .from(SupabaseConfig.usersTable)
        .update(updates)
        .eq('uid', userId)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    // Note: This should be handled via a Supabase Edge Function
    // for proper cleanup of user data
    await signOut();
  }
}
