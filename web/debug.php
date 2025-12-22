<?php
require_once 'includes/config.php';

header('Content-Type: text/plain');

$code = isset($_GET['code']) ? $_GET['code'] : 'DR5XWFLB';

echo "=== Testing Invite Code: $code ===\n\n";

// Test 1: Get invite link
echo "1. Getting invite link...\n";
$invite = supabase_get('invite_links', [
    'select' => '*',
    'code' => 'eq.' . strtoupper($code),
    'is_active' => 'eq.true'
]);
echo "Invite result: " . print_r($invite, true) . "\n";

if (!empty($invite) && is_array($invite) && count($invite) > 0) {
    $inviteData = $invite[0];
    
    // Test 2: Get owner info
    echo "\n2. Getting owner info (owner_id: {$inviteData['owner_id']})...\n";
    $owner = supabase_get('users', [
        'select' => 'display_name,avatar_url',
        'uid' => 'eq.' . $inviteData['owner_id']
    ]);
    echo "Owner result: " . print_r($owner, true) . "\n";
    
    // Test 3: Get list info if list_id exists
    if (!empty($inviteData['list_id'])) {
        echo "\n3. Getting list info (list_id: {$inviteData['list_id']})...\n";
        $list = supabase_get('lists', [
            'select' => 'title',
            'id' => 'eq.' . $inviteData['list_id']
        ]);
        echo "List result: " . print_r($list, true) . "\n";
    }
}

echo "\n=== Testing get_invite_by_code function ===\n";
$fullInvite = get_invite_by_code($code);
echo "Full invite: " . print_r($fullInvite, true) . "\n";
?>
