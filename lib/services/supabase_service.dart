import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';

/// Supabase service for managing database operations
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // Test mode for app store reviewers - bypasses Supabase auth entirely
  static bool _isOfflineTestMode = false;
  static bool get isOfflineTestMode => _isOfflineTestMode;
  
  // Hardcoded test user UID (must match a real user in Supabase for data access)
  // If this user doesn't exist, test mode will show empty data states
  static const String testUserUid = 'test-user-00000000-0000-0000-0000-000000000001';
  
  /// Enable offline test mode (bypasses all Supabase auth)
  static void enableOfflineTestMode() {
    _isOfflineTestMode = true;
  }
  
  /// Disable offline test mode
  static void disableOfflineTestMode() {
    _isOfflineTestMode = false;
  }

  /// Initialize Supabase with project credentials
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  /// Get the current authenticated user
  static User? get currentUser => client.auth.currentUser;

  /// Get the current user's ID (returns test UID if in offline test mode)
  static String? get currentUserId {
    if (_isOfflineTestMode) return testUserUid;
    return currentUser?.id;
  }

  /// Check if user is authenticated (true if in offline test mode)
  static bool get isAuthenticated {
    if (_isOfflineTestMode) return true;
    return currentUser != null;
  }

  /// Get auth state stream
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  // Database helpers
  static SupabaseQueryBuilder table(String tableName) => client.from(tableName);

  // Storage helpers
  static SupabaseStorageClient get storage => client.storage;

  // Realtime helpers
  static RealtimeClient get realtime => client.realtime;
}


