/// Supabase Configuration
/// Replace these values with your actual Supabase project credentials
class SupabaseConfig {
  SupabaseConfig._();

  // TODO: Replace with your Supabase URL from your project settings
  static const String supabaseUrl = 'https://fvzcdnxvbsvamtruyhby.supabase.co';

  // TODO: Replace with your Supabase anon key from your project settings
  static const String supabaseAnonKey =
      'sb_publishable_vUguYwCiSl-5XunqzqoerA_WKeJdCj4';

  // Database Tables
  static const String usersTable = 'users';
  static const String listsTable = 'lists';
  static const String listItemsTable = 'list_items';
  static const String commitsTable = 'commits';
  static const String listSharesTable = 'list_shares';
  static const String messagesTable = 'messages';
  static const String conversationsTable = 'conversations';
  static const String conversationParticipantsTable =
      'conversation_participants';
  static const String friendsTable = 'friends';

  // Database Views
  static const String publicListItemsView = 'public_list_items';

  // Database Functions
  static const String claimItemFunction = 'claim_item';
  static const String unclaimItemFunction = 'unclaim_item';

  // Storage Buckets
  static const String profileImagesBucket = 'profile-images';
  static const String itemImagesBucket = 'item-images';
}
