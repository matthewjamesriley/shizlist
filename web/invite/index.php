<?php
require_once '../includes/config.php';

// Get invite code from URL
$code = isset($_GET['code']) ? $_GET['code'] : '';

// If no code in query param, check if it's in the path
if (empty($code)) {
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    $pathParts = explode('/', trim($path, '/'));
    if (count($pathParts) >= 2 && $pathParts[0] === 'invite') {
        $code = $pathParts[1];
    }
}

$invite = null;
$error = null;

if (!empty($code)) {
    $invite = get_invite_by_code($code);
    if (!$invite) {
        $error = 'This invite link is invalid or has expired.';
    }
} else {
    $error = 'No invite code provided.';
}

// Extract data
$ownerName = $invite['users']['display_name'] ?? 'Someone';
$ownerAvatar = $invite['users']['avatar_url'] ?? null;
$lists = $invite['lists'] ?? [];
$listCount = count($lists);
$shareAllLists = !empty($invite['share_all_lists']);

// Build list titles for display
$listTitles = array_map(function($l) { return $l['title'] ?? ''; }, $lists);
$listTitles = array_filter($listTitles); // Remove empty

// Function to get SVG icon based on list title
function getListIconSvg($title) {
    $lowerTitle = strtolower($title);
    
    // Birthday
    if (strpos($lowerTitle, 'birthday') !== false || strpos($lowerTitle, 'bday') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M208,80H136V69.45l13.66-9.1a8,8,0,0,0,2.66-10.79,24,24,0,0,0-40.64,0,8,8,0,0,0,2.66,10.79L128,69.45V80H48A16,16,0,0,0,32,96V200a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM112,56a8,8,0,1,1,8,8A8,8,0,0,1,112,56Zm96,144H48V152H208Zm0-64H48V96H208Z"/></svg>';
    }
    
    // Wedding
    if (strpos($lowerTitle, 'wedding') !== false || strpos($lowerTitle, 'bride') !== false || strpos($lowerTitle, 'groom') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M178,32c-20.65,0-38.73,8.88-50,23.89C116.73,40.88,98.65,32,78,32A62.07,62.07,0,0,0,16,94c0,70,103.79,126.66,108.21,129a8,8,0,0,0,7.58,0C136.21,220.66,240,164,240,94A62.07,62.07,0,0,0,178,32ZM128,206.8C109.74,196.16,32,147.69,32,94A46.06,46.06,0,0,1,78,48c19.45,0,35.78,10.36,42.6,27a8,8,0,0,0,14.8,0c6.82-16.67,23.15-27,42.6-27a46.06,46.06,0,0,1,46,46C224,147.61,146.24,196.15,128,206.8Z"/></svg>';
    }
    
    // Christmas / Gift
    if (strpos($lowerTitle, 'christmas') !== false || strpos($lowerTitle, 'xmas') !== false || strpos($lowerTitle, 'gift') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M216,72H180.92c.39-.33.79-.65,1.17-1A29.53,29.53,0,0,0,192,49.57,32.62,32.62,0,0,0,158.44,16,29.53,29.53,0,0,0,137,25.91a54.94,54.94,0,0,0-9,14.48,54.94,54.94,0,0,0-9-14.48A29.53,29.53,0,0,0,97.56,16,32.62,32.62,0,0,0,64,49.57,29.53,29.53,0,0,0,73.91,71c.38.33.78.65,1.17,1H40A16,16,0,0,0,24,88v32a16,16,0,0,0,16,16v64a16,16,0,0,0,16,16H200a16,16,0,0,0,16-16V136a16,16,0,0,0,16-16V88A16,16,0,0,0,216,72ZM149,36.51a13.69,13.69,0,0,1,10-4.5h.49A16.62,16.62,0,0,1,176,49.08a13.69,13.69,0,0,1-4.5,10c-9.49,8.4-25.24,11.36-35,12.4C137.7,60.89,141,45.5,149,36.51Zm-64.09.36A16.63,16.63,0,0,1,96.59,32h.49a13.69,13.69,0,0,1,10,4.5c8.39,9.48,11.35,25.2,12.39,34.92-9.72-1-25.44-4-34.92-12.39a13.69,13.69,0,0,1-4.5-10A16.6,16.6,0,0,1,84.87,36.87ZM40,88h80v32H40Zm16,48h64v64H56Zm144,64H136V136h64Zm16-80H136V88h80v32Z"/></svg>';
    }
    
    // Baby
    if (strpos($lowerTitle, 'baby') !== false || strpos($lowerTitle, 'shower') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M134.16,24.1a4,4,0,0,0-3.56,1.81C120.3,41.48,120,55.79,120,56a8,8,0,0,0,9.68,7.79A8.24,8.24,0,0,0,136,55.68,8,8,0,0,1,152,56a32,32,0,0,1-64,0,71.47,71.47,0,0,1,3-20.66,4,4,0,0,0-5.17-4.86A72,72,0,1,0,200,120a71.56,71.56,0,0,0-9.54-35.77,4,4,0,0,0-5.79-1.15,4,4,0,0,0-1.29,1.66,8,8,0,0,1-7.38,4.91,8.23,8.23,0,0,1-7.29-5.07l0-.06a24,24,0,0,1,44.29-18.46A87.57,87.57,0,0,1,224,120,88,88,0,0,1,47,175a4,4,0,0,0-5.79-1.14,4,4,0,0,0-1.54,3.31,104,104,0,1,0,94.49-153Z"/></svg>';
    }
    
    // Graduation
    if (strpos($lowerTitle, 'graduation') !== false || strpos($lowerTitle, 'grad') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M251.76,88.94l-120-64a8,8,0,0,0-7.52,0l-120,64a8,8,0,0,0,0,14.12L32,117.87v48.42a15.91,15.91,0,0,0,4.06,10.65C49.16,191.53,78.51,216,128,216a130.36,130.36,0,0,0,48-8.76V240a8,8,0,0,0,16,0V199.51a115.63,115.63,0,0,0,27.94-22.57A15.91,15.91,0,0,0,224,166.29V117.87l27.76-14.81a8,8,0,0,0,0-14.12ZM128,200c-43.27,0-68.72-21.14-80-33.71V126.4l76.24,40.66a8,8,0,0,0,7.52,0L176,143.47v46.34C163.4,195.69,147.52,200,128,200Zm80-33.75a97.83,97.83,0,0,1-16,14.25V134.93l16-8.53ZM188,118.94l-.22-.13-56-29.87a8,8,0,0,0-7.52,14.12L168,128l-40,21.33L48,107.09V95.94l80,42.67,80-42.67v11.15l-19.78,10.53A8,8,0,0,0,188,118.94ZM45.77,103.44,128,147.06l82.23-43.62,2.77-1.48L128,54.65,43,101.96Z"/></svg>';
    }
    
    // House / Housewarming
    if (strpos($lowerTitle, 'house') !== false || strpos($lowerTitle, 'home') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M218.83,103.77l-80-75.48a1.14,1.14,0,0,1-.11-.11,16,16,0,0,0-21.53,0l-.11.11L37.17,103.77A16,16,0,0,0,32,115.55V208a16,16,0,0,0,16,16H96a16,16,0,0,0,16-16V160h32v48a16,16,0,0,0,16,16h48a16,16,0,0,0,16-16V115.55A16,16,0,0,0,218.83,103.77ZM208,208H160V160a16,16,0,0,0-16-16H112a16,16,0,0,0-16,16v48H48V115.55l.11-.1L128,40l79.9,75.43.11.1Z"/></svg>';
    }
    
    // Travel / Vacation
    if (strpos($lowerTitle, 'travel') !== false || strpos($lowerTitle, 'vacation') !== false || strpos($lowerTitle, 'trip') !== false || strpos($lowerTitle, 'honeymoon') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M235.58,128.84,160,91.06V48a32,32,0,0,0-64,0V91.06L20.42,128.84A8,8,0,0,0,16,136v32a8,8,0,0,0,9.57,7.84L96,161.76v18.93L82.34,194.34A8,8,0,0,0,80,200v32a8,8,0,0,0,11,7.43l37-14.81,37,14.81A8,8,0,0,0,176,232V200a8,8,0,0,0-2.34-5.66L160,180.69V161.76l70.43,14.08A8,8,0,0,0,240,168V136A8,8,0,0,0,235.58,128.84ZM224,158.24l-70.43-14.08A8,8,0,0,0,144,152v32a8,8,0,0,0,2.34,5.66L160,203.31v16.87l-29-11.61a8,8,0,0,0-5.94,0L96,220.18V203.31l13.66-13.65A8,8,0,0,0,112,184V152a8,8,0,0,0-9.57-7.84L32,158.24V141.06l75.58-37.79A8,8,0,0,0,112,96V48a16,16,0,0,1,32,0V96a8,8,0,0,0,4.42,7.16L224,141.06Z"/></svg>';
    }
    
    // Anniversary / Heart
    if (strpos($lowerTitle, 'anniversary') !== false || strpos($lowerTitle, 'valentine') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M178,32c-20.65,0-38.73,8.88-50,23.89C116.73,40.88,98.65,32,78,32A62.07,62.07,0,0,0,16,94c0,70,103.79,126.66,108.21,129a8,8,0,0,0,7.58,0C136.21,220.66,240,164,240,94A62.07,62.07,0,0,0,178,32ZM128,206.8C109.74,196.16,32,147.69,32,94A46.06,46.06,0,0,1,78,48c19.45,0,35.78,10.36,42.6,27a8,8,0,0,0,14.8,0c6.82-16.67,23.15-27,42.6-27a46.06,46.06,0,0,1,46,46C224,147.61,146.24,196.15,128,206.8Z"/></svg>';
    }
    
    // Party
    if (strpos($lowerTitle, 'party') !== false || strpos($lowerTitle, 'new year') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M111.49,52.63a15.8,15.8,0,0,0-26,5.77L33,202.78A15.83,15.83,0,0,0,47.76,224a16,16,0,0,0,5.46-1l144.37-52.5a15.8,15.8,0,0,0,5.78-26Zm-8.33,135.21-35-35,13.16-36.21,58.05,58.05Zm-55,20,14-14a8,8,0,0,0-11.31-11.31l-14,14L19.7,230.3a8,8,0,0,0,11.31,11.31Zm186.47-70.47-14,14a8,8,0,0,0,11.31,11.31l14-14a8,8,0,0,0-11.31-11.31ZM208,76a27.87,27.87,0,0,0,5.66-.58,8,8,0,0,0-3.32-15.66A12,12,0,1,1,196,48a8,8,0,0,0,0-16,28,28,0,1,0,12,53.34Zm37.66-34.34a8,8,0,0,0-11.32,0L220,56a8,8,0,0,0,11.31,11.31l14.35-14.34A8,8,0,0,0,245.66,41.66ZM248,88H232a8,8,0,0,0,0,16h16a8,8,0,0,0,0-16Z"/></svg>';
    }
    
    // Engagement / Diamond
    if (strpos($lowerTitle, 'engagement') !== false || strpos($lowerTitle, 'engaged') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M246,98.73l-56-64A8,8,0,0,0,184,32H72a8,8,0,0,0-6,2.73l-56,64a8,8,0,0,0,.17,10.73l112,120a8,8,0,0,0,11.7,0l112-120A8,8,0,0,0,246,98.73ZM222.37,96H180L156,48h36.71ZM63.29,48H100L76,96H33.63ZM96,112l32,72L96,112Zm16,0h32l-16,36Zm48,0,32,72-32-72Zm-32-16L112,48h32l16,48Zm68-48h12.71l-20,48H180Z"/></svg>';
    }
    
    // Shopping / Stuff
    if (strpos($lowerTitle, 'shopping') !== false || strpos($lowerTitle, 'stuff') !== false) {
        return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M216,64H176a48,48,0,0,0-96,0H40A16,16,0,0,0,24,80V200a16,16,0,0,0,16,16H216a16,16,0,0,0,16-16V80A16,16,0,0,0,216,64ZM128,32a32,32,0,0,1,32,32H96A32,32,0,0,1,128,32Zm88,168H40V80H80V96a8,8,0,0,0,16,0V80h64V96a8,8,0,0,0,16,0V80h40Z"/></svg>';
    }
    
    // Default - users icon
    return '<svg viewBox="0 0 256 256" fill="currentColor"><path d="M117.25,157.92a60,60,0,1,0-66.5,0A95.83,95.83,0,0,0,3.53,195.63a8,8,0,1,0,13.4,8.74,80,80,0,0,1,134.14,0,8,8,0,0,0,13.4-8.74A95.83,95.83,0,0,0,117.25,157.92ZM40,108a44,44,0,1,1,44,44A44.05,44.05,0,0,1,40,108Zm210.14,98.7a8,8,0,0,1-11.07-2.33A79.83,79.83,0,0,0,172,168a8,8,0,0,1,0-16,44,44,0,1,0-16.34-84.87,8,8,0,1,1-5.94-14.85,60,60,0,0,1,55.53,105.64,95.83,95.83,0,0,1,47.22,37.71A8,8,0,0,1,250.14,206.7Z"/></svg>';
}

// App store links
$appStoreUrl = 'https://apps.apple.com/gb/app/shizlist/id6756820711';
$playStoreUrl = 'https://play.google.com/store/apps/details?id=co.shizlist.app';
$appDeepLink = 'co.shizlist.app://invite/' . $code;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShizList Invite<?php echo $listCount == 1 ? ' - ' . htmlspecialchars($listTitles[0] ?? '') : ($listCount > 1 ? ' - ' . $listCount . ' lists' : ''); ?></title>
    
    <!-- Favicon -->
    <link rel="icon" type="image/png" href="/images/app_icon.png">
    <link rel="apple-touch-icon" href="/images/app_icon.png">
    
    <!-- Open Graph / Social Sharing -->
    <meta property="og:title" content="<?php echo htmlspecialchars($ownerName); ?> invited you to ShizList">
    <meta property="og:description" content="<?php 
        if ($listCount == 1) {
            echo 'Join ' . htmlspecialchars($ownerName) . '\'s list: ' . htmlspecialchars($listTitles[0] ?? '');
        } elseif ($listCount > 1) {
            echo 'Join ' . $listCount . ' lists from ' . htmlspecialchars($ownerName);
        } elseif ($shareAllLists) {
            echo 'View all of ' . htmlspecialchars($ownerName) . '\'s lists';
        } else {
            echo 'Connect with ' . htmlspecialchars($ownerName) . ' on ShizList';
        }
    ?>">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://shizlist.co/invite/<?php echo htmlspecialchars($code); ?>">
    <meta property="og:image" content="https://shizlist.co/images/og-invite.png">
    
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Source+Sans+3:wght@400;600&display=swap" rel="stylesheet">
    
    <style>
        :root {
            --primary: #009688;
            --accent: #FF5722;
            --background: #FAFAFA;
            --text-primary: #212121;
            --text-secondary: #757575;
            --surface: #FFFFFF;
            --error: #D32F2F;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Source Sans 3', -apple-system, BlinkMacSystemFont, sans-serif;
            background: #ffffff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: var(--text-primary);
        }
        
        .container {
            background: #f5f2e9;
            border-radius: 24px;
            max-width: 420px;
            width: 100%;
            padding: 48px 32px;
            text-align: center;
        }
        
        .header-row {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 30px;
            margin-top: -30px;
        }
        
        .logo img {
            height: 140px;
            width: auto;
        }
        
        .avatar {
            width: 100px;
            height: 100px;
            border-radius: 50%;
            background: var(--primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
            color: white;
            font-weight: 600;
            overflow: hidden;
            flex-shrink: 0;
        }
        
        .avatar img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .avatar-fallback,
        .avatar-initial {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 100%;
            height: 100%;
        }
        
        .invite-message {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 8px;
            color: var(--text-primary);
        }
        
        .invite-detail {
            font-size: 16px;
            color: var(--text-primary);
            margin-bottom: 24px;
            line-height: 1.5;
        }
        
        .lists-preview {
            background: rgba(255,255,255,0.6);
            border-radius: 12px;
            padding: 16px;
            margin-bottom: 24px;
            text-align: left;
        }
        
        .lists-preview-title {
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 10px;
        }
        
        .list-item {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 8px 0;
        }
        
        .list-item:not(:last-child) {
            border-bottom: 1px solid rgba(0,0,0,0.08);
        }
        
        .list-icon {
            width: 28px;
            height: 28px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .list-icon svg {
            width: 22px;
            height: 22px;
            fill: var(--primary);
        }
        
        .list-name {
            font-size: 15px;
            font-weight: 500;
            color: var(--text-primary);
        }
        
        .cta-button {
            display: block;
            width: 100%;
            padding: 16px 32px;
            background: var(--accent);
            color: white;
            border: none;
            border-radius: 28px;
            font-size: 18px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: transform 0.2s, box-shadow 0.2s;
            margin-bottom: 16px;
        }
        
        .cta-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(255, 87, 34, 0.3);
        }
        
        .cta-button.secondary {
            background: transparent;
            color: var(--text-primary);
            border: 2px solid var(--text-secondary);
        }
        
        .cta-button.secondary:hover {
            border-color: var(--text-primary);
            box-shadow: none;
        }
        
        .store-buttons {
            display: flex;
            gap: 12px;
            margin-top: 24px;
        }
        
        .store-button {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 12px 16px;
            background: #000;
            color: white;
            border-radius: 12px;
            text-decoration: none;
            font-size: 12px;
            font-weight: 600;
            transition: opacity 0.2s;
        }
        
        .store-button:hover {
            opacity: 0.8;
        }
        
        .store-button svg {
            width: 24px;
            height: 24px;
        }
        
        .store-button .store-text {
            text-align: left;
            line-height: 1.2;
        }
        
        .store-button .store-text small {
            font-size: 10px;
            font-weight: 400;
            opacity: 0.8;
        }
        
        .divider {
            display: flex;
            align-items: center;
            margin: 24px 0;
            color: var(--text-secondary);
            font-size: 14px;
        }
        
        .divider::before,
        .divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #e0e0e0;
        }
        
        .divider span {
            padding: 0 16px;
        }
        
        .error-container {
            text-align: center;
        }
        
        .error-icon {
            margin-bottom: 24px;
        }
        
        .error-icon img {
            height: 150px;
            width: auto;
        }
        
        .error-message {
            font-size: 18px;
            color: var(--error);
            margin-bottom: 24px;
        }
        
        .tagline {
            font-size: 14px;
            color: var(--text-secondary);
            margin-top: 32px;
        }
        
        /* Desktop message */
        .desktop-message {
            display: none;
        }
        
        .desktop-message .qr-code {
            margin-bottom: 20px;
        }
        
        .desktop-message .qr-code img {
            width: 180px;
            height: 180px;
            border-radius: 12px;
            border: 3px solid var(--primary);
            padding: 8px;
            background: white;
        }
        
        .desktop-message p {
            font-size: 16px;
            color: var(--text-secondary);
            margin-bottom: 24px;
            line-height: 1.5;
        }
        
        /* Mobile content */
        .mobile-content {
            display: block;
        }
        
        /* Show/hide based on device - JS will handle this */
        body.is-desktop .mobile-content {
            display: none;
        }
        
        body.is-desktop .desktop-message {
            display: block;
        }
        
        @media (max-width: 480px) {
            .container {
                padding: 32px 24px;
            }
            
            .invite-message {
                font-size: 20px;
            }
            
            .store-buttons {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <?php if ($error): ?>
            <div class="logo" style="margin-bottom: 32px;">
                <img src="/images/Logo-Full.png" alt="ShizList">
            </div>
            <div class="error-container">
                <div class="error-icon">
                    <img src="/images/sad-monster.png" alt="Oops">
                </div>
                <p class="error-message"><?php echo htmlspecialchars($error); ?></p>
                <a href="https://shizlist.co" class="cta-button">Go to ShizList</a>
            </div>
        <?php else: ?>
            <div class="header-row">
                <div class="logo">
                    <img src="/images/Logo-Full.png" alt="ShizList">
                </div>
                <div class="avatar">
                    <?php if (!empty($ownerAvatar)): ?>
                        <img src="<?php echo htmlspecialchars($ownerAvatar); ?>" alt="<?php echo htmlspecialchars($ownerName); ?>" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
                        <span class="avatar-fallback" style="display:none;"><?php echo strtoupper(substr($ownerName, 0, 1)); ?></span>
                    <?php else: ?>
                        <span class="avatar-initial"><?php echo strtoupper(substr($ownerName, 0, 1)); ?></span>
                    <?php endif; ?>
                </div>
            </div>
            
            <h1 class="invite-message">
                <?php echo htmlspecialchars($ownerName); ?> invited you!
            </h1>
            
            <p class="invite-detail">
                <?php if ($listCount == 1): ?>
                    You've been invited to join the <strong>"<?php echo htmlspecialchars($listTitles[0]); ?>"</strong> list.
                <?php elseif ($listCount > 1): ?>
                    You've been invited to join <?php echo $listCount; ?> lists from <?php echo htmlspecialchars($ownerName); ?>.
                <?php elseif ($shareAllLists): ?>
                    You've been invited to view all of <?php echo htmlspecialchars($ownerName); ?>'s lists.
                <?php else: ?>
                    You've been invited to connect on ShizList - the best way to share wish lists with friends and family.
                <?php endif; ?>
            </p>
            
            <?php if ($listCount > 0): ?>
            <div class="lists-preview">
                <div class="lists-preview-title">Lists you'll be added to</div>
                <?php foreach ($lists as $list): ?>
                <div class="list-item">
                    <div class="list-icon">
                        <?php echo getListIconSvg($list['title'] ?? ''); ?>
                    </div>
                    <span class="list-name"><?php echo htmlspecialchars($list['title'] ?? 'Untitled List'); ?></span>
                </div>
                <?php endforeach; ?>
            </div>
            <?php endif; ?>
            
            <!-- Desktop Message -->
            <div class="desktop-message">
                <div class="qr-code">
                    <img src="https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=<?php echo urlencode('https://shizlist.co/invite/' . $code); ?>" alt="Scan to accept invite">
                </div>
                <p>Scan this QR code with your phone to accept the invitation and connect with <?php echo htmlspecialchars($ownerName); ?>.</p>
                
                <div class="divider"><span>Get the app</span></div>
                
                <div class="store-buttons">
                    <a href="<?php echo $appStoreUrl; ?>" class="store-button">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                        </svg>
                        <div class="store-text">
                            <small>Download on the</small><br>
                            App Store
                        </div>
                    </a>
                    <a href="<?php echo $playStoreUrl; ?>" class="store-button">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                        </svg>
                        <div class="store-text">
                            <small>Get it on</small><br>
                            Google Play
                        </div>
                    </a>
                </div>
            </div>
            
            <!-- Mobile Content -->
            <div class="mobile-content">
                <a href="<?php echo $appDeepLink; ?>" class="cta-button" id="acceptInvite">
                    Accept Invitation
                </a>
                
                <div class="divider"><span>Don't have the app?</span></div>
                
                <div class="store-buttons">
                    <a href="<?php echo $appStoreUrl; ?>" class="store-button">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                        </svg>
                        <div class="store-text">
                            <small>Download on the</small><br>
                            App Store
                        </div>
                    </a>
                    <a href="<?php echo $playStoreUrl; ?>" class="store-button">
                        <svg viewBox="0 0 24 24" fill="currentColor">
                            <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                        </svg>
                        <div class="store-text">
                            <small>Get it on</small><br>
                            Google Play
                        </div>
                    </a>
                </div>
                
                <p class="tagline">Share the stuff you love</p>
            </div>
        <?php endif; ?>
    </div>
    
    <script>
        // Detect if user is on mobile or desktop
        function isMobileDevice() {
            return /iPhone|iPad|iPod|Android|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
        }
        
        // Add class to body based on device type
        if (!isMobileDevice()) {
            document.body.classList.add('is-desktop');
        }
    </script>
</body>
</html>
