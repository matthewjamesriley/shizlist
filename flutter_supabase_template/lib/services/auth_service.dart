import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_profile.dart';
import '../core/constants/supabase_config.dart';

/// Supported OAuth providers
enum SocialProvider { google, apple, facebook }

/// Authentication service for handling user auth operations
class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  // ============================================
  // TODO: Update the redirect URL for your app
  // Format: your.bundle.id://login-callback
  // ============================================
  static const String _redirectUrl = 'com.example.myapp://login-callback';

  /// Send magic link / OTP to email (passwordless auth)
  /// This works for both sign up and sign in
  Future<void> signInWithOtp({
    required String email,
    String? displayName,
  }) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: kIsWeb ? null : _redirectUrl,
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  /// Verify OTP code
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );

    // Ensure user profile exists
    if (response.user != null) {
      await ensureUserProfileExists(
        userId: response.user!.id,
        email: response.user!.email ?? email,
        displayName: response.user!.userMetadata?['display_name'] as String?,
      );
    }

    return response;
  }

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

    if (response.user != null) {
      await ensureUserProfileExists(
        userId: response.user!.id,
        email: email,
        displayName: displayName,
      );
    }

    return response;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await ensureUserProfileExists(
        userId: response.user!.id,
        email: response.user!.email ?? email,
        displayName: response.user!.userMetadata?['display_name'] as String?,
      );
    }

    return response;
  }

  /// Ensure user profile exists in public.users table
  Future<void> ensureUserProfileExists({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    try {
      final existing =
          await _client
              .from(SupabaseConfig.usersTable)
              .select('uid')
              .eq('uid', userId)
              .maybeSingle();

      if (existing == null) {
        await _client.from(SupabaseConfig.usersTable).insert({
          'uid': userId,
          'email': email,
          'display_name': displayName ?? email.split('@').first,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Created user profile for $userId');
      }
    } catch (e) {
      debugPrint('ensureUserProfileExists: $e');
    }
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
      redirectTo: kIsWeb ? null : _redirectUrl,
      authScreenLaunchMode: LaunchMode.platformDefault,
    );

    return response;
  }

  /// Called when auth state changes (for OAuth flows)
  Future<void> onAuthStateChanged(User? user) async {
    if (user != null) {
      await ensureUserProfileExists(
        userId: user.id,
        email: user.email ?? '',
        displayName:
            user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String?,
      );
    }
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
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Check if an email already exists
  Future<bool> emailExists(String email) async {
    final response = await _client
        .from(SupabaseConfig.usersTable)
        .select('id')
        .eq('email', email.toLowerCase())
        .maybeSingle();
    return response != null;
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    final response =
        await _client
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
    String? currencyCode,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl.isEmpty ? null : avatarUrl;
    }
    if (currencyCode != null) updates['currency_code'] = currencyCode;

    final response =
        await _client
            .from(SupabaseConfig.usersTable)
            .update(updates)
            .eq('uid', userId)
            .select()
            .single();

    return UserProfile.fromJson(response);
  }

  /// Update user's currency preference
  Future<UserProfile> updateUserCurrency(String currencyCode) async {
    return updateUserProfile(currencyCode: currencyCode);
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    // Note: Should be handled via a Supabase Edge Function
    await signOut();
  }
}




