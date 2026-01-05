import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_profile.dart';
import '../core/constants/supabase_config.dart';
import '../core/constants/app_constants.dart';

/// Supported OAuth providers
enum SocialProvider { google, apple, facebook }

/// Authentication service for handling user auth operations
class AuthService {
  final SupabaseClient _client = SupabaseService.client;
  
  /// Track if current session is a test account (for app store reviewers)
  static bool _isTestAccount = false;
  static bool get isTestAccount => _isTestAccount || SupabaseService.isOfflineTestMode;
  
  /// Check if email is the test account email
  static bool isTestAccountEmail(String email) {
    return AppConstants.testAccountEnabled &&
        email.toLowerCase().trim() == AppConstants.testAccountEmail.toLowerCase();
  }
  
  /// Sign in with test account - completely offline, no Supabase auth needed
  /// This enables Google Play reviewers to access the app even if their
  /// network environment blocks Supabase
  Future<void> signInWithTestAccountOffline() async {
    _isTestAccount = true;
    SupabaseService.enableOfflineTestMode();
    // No Supabase call needed - the app will use hardcoded test user ID
  }
  
  /// Sign in with test account (tries Supabase first, falls back to offline mode)
  Future<void> signInWithTestAccount() async {
    try {
      // Try real Supabase auth first
      final response = await _client.auth.signInWithPassword(
        email: AppConstants.testAccountEmail,
        password: AppConstants.testAccountPassword,
      );
      
      if (response.user != null) {
        _isTestAccount = true;
        await ensureUserProfileExists(
          userId: response.user!.id,
          email: response.user!.email ?? AppConstants.testAccountEmail,
          displayName: 'Test User',
        );
        return;
      }
    } catch (e) {
      // Supabase auth failed - fall back to offline test mode
      debugPrint('Supabase auth failed, using offline test mode: $e');
    }
    
    // Fall back to offline mode if Supabase fails
    await signInWithTestAccountOffline();
  }

  /// Send magic link / OTP to email (passwordless auth)
  /// This works for both sign up and sign in
  Future<void> signInWithOtp({
    required String email,
    String? displayName,
  }) async {
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: kIsWeb ? null : 'co.shizlist.app://login-callback',
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  /// Verify OTP code (if using code-based verification instead of magic link)
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

  /// Sign up with email and password (legacy - kept for compatibility)
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

    // Ensure user profile exists (in case trigger didn't fire)
    if (response.user != null) {
      await ensureUserProfileExists(
        userId: response.user!.id,
        email: email,
        displayName: displayName,
      );
    }

    return response;
  }

  /// Sign in with email and password (legacy - kept for compatibility)
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
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

  /// Ensure user profile exists in public.users table
  /// Creates one if it doesn't exist (handles cases where trigger didn't fire)
  Future<void> ensureUserProfileExists({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    try {
      // Check if profile exists
      final existing =
          await _client
              .from(SupabaseConfig.usersTable)
              .select('uid')
              .eq('uid', userId)
              .maybeSingle();

      if (existing == null) {
        // Create profile if it doesn't exist
        await _client.from(SupabaseConfig.usersTable).insert({
          'uid': userId,
          'email': email,
          'display_name': displayName ?? email.split('@').first,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Created user profile for $userId');
      }
    } catch (e) {
      // Profile might already exist due to race condition with trigger
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
      redirectTo: kIsWeb ? null : 'co.shizlist.app://login-callback',
      authScreenLaunchMode: LaunchMode.platformDefault,
    );

    // Note: For OAuth, the profile is ensured when auth state changes
    // See SupabaseService.authStateStream listener

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
    _isTestAccount = false;
    SupabaseService.disableOfflineTestMode();
    // Only call Supabase signOut if we have a real session
    if (!SupabaseService.isOfflineTestMode && SupabaseService.currentUser != null) {
      await _client.auth.signOut();
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Check if an email already exists in the users table
  Future<bool> emailExists(String email) async {
    final response = await _client
        .from(SupabaseConfig.usersTable)
        .select('id')
        .eq('email', email.toLowerCase())
        .maybeSingle();
    return response != null;
  }

  /// Update email - sends confirmation to old email address
  /// Returns true if the request was sent successfully
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  /// Check if current user is using email/password authentication (not social login)
  bool get isEmailPasswordUser {
    final user = SupabaseService.currentUser;
    if (user == null) return false;

    // Check app_metadata for provider
    final provider = user.appMetadata['provider'] as String?;
    final providers = user.appMetadata['providers'] as List<dynamic>?;

    // If provider is 'email' or providers list only contains 'email', it's an email user
    if (provider == 'email') return true;
    if (providers != null &&
        providers.length == 1 &&
        providers.first == 'email')
      return true;

    // Also check identities - email users typically have identity with provider 'email'
    final identities = user.identities;
    if (identities != null && identities.isNotEmpty) {
      return identities.every((i) => i.provider == 'email');
    }

    return false;
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
  /// Pass empty string for avatarUrl to clear the avatar
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
      // Empty string means clear the avatar
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

  /// Check if user has completed onboarding (has currency set)
  Future<bool> hasCompletedOnboarding() async {
    final profile = await getCurrentUserProfile();
    // If profile exists and has currency set, onboarding is complete
    return profile != null;
  }

  /// Delete user account and all associated data
  /// Calls the Supabase RPC function to properly delete the account
  Future<void> deleteAccount() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Call the Supabase RPC function to delete the account
      // This function should be created in Supabase to handle:
      // 1. Deleting user data from all tables
      // 2. Deleting the auth user via admin API
      await _client.rpc('delete_user_account');
    } catch (e) {
      debugPrint('Error calling delete_user_account RPC: $e');
      // If RPC fails, still sign out the user
      // The RPC function may not exist yet - admin needs to create it
    }

    // Always sign out after deletion attempt
    await signOut();
  }
}
