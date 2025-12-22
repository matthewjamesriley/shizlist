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
$listTitle = $invite['lists']['title'] ?? null;
$hasListShare = !empty($listTitle);

// App store links
$appStoreUrl = 'https://apps.apple.com/app/shizlist/id123456789'; // Replace with actual
$playStoreUrl = 'https://play.google.com/store/apps/details?id=co.shizlist.app';
$appDeepLink = 'co.shizlist.app://invite/' . $code;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShizList Invite<?php echo $hasListShare ? ' - ' . htmlspecialchars($listTitle) : ''; ?></title>
    
    <!-- Favicon -->
    <link rel="icon" type="image/png" href="/images/app_icon.png">
    <link rel="apple-touch-icon" href="/images/app_icon.png">
    
    <!-- Open Graph / Social Sharing -->
    <meta property="og:title" content="<?php echo htmlspecialchars($ownerName); ?> invited you to ShizList">
    <meta property="og:description" content="<?php echo $hasListShare ? 'Join ' . htmlspecialchars($ownerName) . '\'s list: ' . htmlspecialchars($listTitle) : 'Share the stuff you love with ShizList'; ?>">
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
            background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            color: var(--text-primary);
        }
        
        .container {
            background: var(--surface);
            border-radius: 24px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
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
            margin-bottom: 32px;
            line-height: 1.5;
        }
        
        .cta-button {
            display: block;
            width: 100%;
            padding: 16px 32px;
            background: var(--primary);
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
            box-shadow: 0 8px 24px rgba(0, 150, 136, 0.3);
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
            font-size: 64px;
            margin-bottom: 24px;
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
                <img src="/images/ShizList-Splash.jpg" alt="ShizList">
            </div>
            <div class="error-container">
                <div class="error-icon">😕</div>
                <p class="error-message"><?php echo htmlspecialchars($error); ?></p>
                <a href="https://shizlist.co" class="cta-button">Go to ShizList</a>
            </div>
        <?php else: ?>
            <div class="header-row">
                <div class="logo">
                    <img src="/images/ShizList-Splash.jpg" alt="ShizList">
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
                <?php if ($hasListShare): ?>
                    You've been invited to the <strong>"<?php echo htmlspecialchars($listTitle); ?>"</strong> ShizList.
                <?php else: ?>
                    You've been invited to join ShizList - the best way to share wish lists with friends and family.
                <?php endif; ?>
            </p>
            
            <a href="<?php echo $appDeepLink; ?>" class="cta-button" id="openApp">
                Open in ShizList App
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
            
            <p class="tagline">Share the stuff you love ❤️</p>
        <?php endif; ?>
    </div>
    
    <script>
        // Try to open the app first, then fall back to showing the page
        document.getElementById('openApp')?.addEventListener('click', function(e) {
            // On mobile, try the deep link
            if (/iPhone|iPad|iPod|Android/i.test(navigator.userAgent)) {
                window.location.href = '<?php echo $appDeepLink; ?>';
                
                // If app doesn't open after 2 seconds, the page stays visible
                setTimeout(function() {
                    // User is still here, app probably not installed
                }, 2000);
            }
        });
    </script>
</body>
</html>

