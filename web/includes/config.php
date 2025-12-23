<?php
/**
 * Supabase Configuration
 * Replace with your actual Supabase credentials
 */

define('SUPABASE_URL', 'https://fvzcdnxvbsvamtruyhby.supabase.co');
define('SUPABASE_ANON_KEY', 'sb_publishable_vUguYwCiSl-5XunqzqoerA_WKeJdCj4');

/**
 * Make a GET request to Supabase
 */
function supabase_get($endpoint, $params = []) {
    $url = SUPABASE_URL . '/rest/v1/' . $endpoint;
    
    if (!empty($params)) {
        $url .= '?' . http_build_query($params);
    }
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'apikey: ' . SUPABASE_ANON_KEY,
        'Authorization: Bearer ' . SUPABASE_ANON_KEY,
        'Content-Type: application/json',
        'Prefer: return=representation'
    ]);
    // SSL fix for local development
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode >= 200 && $httpCode < 300) {
        return json_decode($response, true);
    }
    
    return null;
}

/**
 * Get invite link by code
 */
function get_invite_by_code($code) {
    $code = strtoupper(trim($code));
    
    // Simple query first - just get the invite
    $result = supabase_get('invite_links', [
        'select' => '*',
        'code' => 'eq.' . $code,
        'is_active' => 'eq.true'
    ]);
    
    // Debug - uncomment to see what's happening
    // error_log('Invite query for code: ' . $code);
    // error_log('Result: ' . print_r($result, true));
    
    if (!empty($result) && is_array($result) && count($result) > 0) {
        $invite = $result[0];
        
        // Get owner info separately
        if (!empty($invite['owner_id'])) {
            $owner = supabase_get('users', [
                'select' => 'display_name,avatar_url',
                'uid' => 'eq.' . $invite['owner_id']
            ]);
            if (!empty($owner) && is_array($owner) && count($owner) > 0) {
                $invite['users'] = $owner[0];
            }
        }
        
        // Get list info separately if list_id exists
        if (!empty($invite['list_id'])) {
            $list = supabase_get('lists', [
                'select' => 'title',
                'id' => 'eq.' . $invite['list_id']
            ]);
            if (!empty($list) && is_array($list) && count($list) > 0) {
                $invite['lists'] = $list[0];
            }
        }
        
        return $invite;
    }
    
    return null;
}

/**
 * Get owner info by invite
 */
function get_owner_info($owner_id) {
    $result = supabase_get('users', [
        'select' => 'display_name,avatar_url',
        'uid' => 'eq.' . $owner_id,
        'limit' => 1
    ]);
    
    if (!empty($result) && is_array($result)) {
        return $result[0];
    }
    
    return null;
}

/**
 * Make a POST request to Supabase
 */
function supabase_post($endpoint, $data) {
    $url = SUPABASE_URL . '/rest/v1/' . $endpoint;
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'apikey: ' . SUPABASE_ANON_KEY,
        'Authorization: Bearer ' . SUPABASE_ANON_KEY,
        'Content-Type: application/json',
        'Prefer: return=representation'
    ]);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode >= 200 && $httpCode < 300) {
        return json_decode($response, true);
    }
    
    return null;
}

/**
 * Get user by email
 */
function get_user_by_email($email) {
    $email = strtolower(trim($email));
    $result = supabase_get('users', [
        'select' => 'uid,display_name,avatar_url',
        'email' => 'eq.' . $email
    ]);
    
    if (!empty($result) && is_array($result) && count($result) > 0) {
        return $result[0];
    }
    
    return null;
}

/**
 * Check if friendship already exists
 */
function friendship_exists($user_id, $friend_user_id) {
    // Check both directions
    $result1 = supabase_get('friends', [
        'select' => 'id',
        'user_id' => 'eq.' . $user_id,
        'friend_user_id' => 'eq.' . $friend_user_id
    ]);
    
    if (!empty($result1) && is_array($result1) && count($result1) > 0) {
        return true;
    }
    
    $result2 = supabase_get('friends', [
        'select' => 'id',
        'user_id' => 'eq.' . $friend_user_id,
        'friend_user_id' => 'eq.' . $user_id
    ]);
    
    if (!empty($result2) && is_array($result2) && count($result2) > 0) {
        return true;
    }
    
    return false;
}

/**
 * Create friendship
 */
function create_friendship($user_id, $friend_user_id) {
    return supabase_post('friends', [
        'user_id' => $user_id,
        'friend_user_id' => $friend_user_id
    ]);
}

/**
 * Share list with user
 */
function share_list_with_user($list_uid, $user_id) {
    // Check if already shared
    $existing = supabase_get('list_shares', [
        'select' => 'id',
        'list_uid' => 'eq.' . $list_uid,
        'shared_with_user_id' => 'eq.' . $user_id
    ]);
    
    if (!empty($existing) && is_array($existing) && count($existing) > 0) {
        return true; // Already shared
    }
    
    return supabase_post('list_shares', [
        'list_uid' => $list_uid,
        'shared_with_user_id' => $user_id,
        'can_edit' => false
    ]);
}

/**
 * Get list UID by ID
 */
function get_list_uid($list_id) {
    $result = supabase_get('lists', [
        'select' => 'uid',
        'id' => 'eq.' . $list_id
    ]);
    
    if (!empty($result) && is_array($result) && count($result) > 0) {
        return $result[0]['uid'];
    }
    
    return null;
}
?>

