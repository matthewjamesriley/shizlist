/// Supabase Configuration
/// Replace these values with your actual Supabase project credentials
class SupabaseConfig {
  SupabaseConfig._();

  // ============================================
  // TODO: Replace with YOUR Supabase credentials
  // Find these in: Supabase Dashboard > Settings > API
  // ============================================
  
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';

  // ============================================
  // Database Tables - Update as you add tables
  // ============================================
  
  static const String usersTable = 'users';
  
  // Add your custom tables here:
  // static const String postsTable = 'posts';
  // static const String commentsTable = 'comments';

  // ============================================
  // Storage Buckets - Update as needed
  // ============================================
  
  static const String profileImagesBucket = 'profile-images';
  
  // Add your custom buckets here:
  // static const String uploadsBucket = 'uploads';
}




