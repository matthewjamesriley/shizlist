import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_config.dart';

/// Supabase service for managing database operations
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

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

  /// Get the current user's ID
  static String? get currentUserId => currentUser?.id;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Get auth state stream
  static Stream<AuthState> get authStateStream => client.auth.onAuthStateChange;

  // Database helpers
  static SupabaseQueryBuilder table(String tableName) => client.from(tableName);

  // Storage helpers
  static SupabaseStorageClient get storage => client.storage;

  // Realtime helpers
  static RealtimeClient get realtime => client.realtime;
}


