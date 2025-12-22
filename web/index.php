<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShizList - Share the stuff you love</title>
    
    <!-- Favicon -->
    <link rel="icon" type="image/png" href="/images/app_icon.png">
    <link rel="apple-touch-icon" href="/images/app_icon.png">
    
    <!-- Open Graph -->
    <meta property="og:title" content="ShizList - Share the stuff you love">
    <meta property="og:description" content="Create and share wish lists with friends and family. The easiest way to coordinate gifting.">
    <meta property="og:type" content="website">
    <meta property="og:url" content="https://shizlist.co">
    <meta property="og:image" content="https://shizlist.co/images/og-home.png">
    
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
            max-width: 500px;
            width: 100%;
            padding: 64px 48px;
            text-align: center;
        }
        
        .logo img {
            height: 50px;
            margin-bottom: 16px;
        }
        
        .tagline {
            font-size: 20px;
            color: var(--text-secondary);
            margin-bottom: 48px;
        }
        
        .description {
            font-size: 16px;
            line-height: 1.6;
            color: var(--text-primary);
            margin-bottom: 48px;
        }
        
        .store-buttons {
            display: flex;
            gap: 16px;
            justify-content: center;
        }
        
        .store-button {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 14px 24px;
            background: #000;
            color: white;
            border-radius: 14px;
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .store-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
        }
        
        .store-button svg {
            width: 28px;
            height: 28px;
        }
        
        .store-button .store-text {
            text-align: left;
            line-height: 1.2;
        }
        
        .store-button .store-text small {
            font-size: 11px;
            font-weight: 400;
            opacity: 0.8;
        }
        
        .footer {
            margin-top: 48px;
            font-size: 14px;
            color: var(--text-secondary);
        }
        
        .footer a {
            color: var(--primary);
            text-decoration: none;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        @media (max-width: 480px) {
            .container {
                padding: 48px 24px;
            }
            
            .logo-text {
                font-size: 36px;
            }
            
            .store-buttons {
                flex-direction: column;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo"><img src="/images/ShizList-Splash.jpg" alt="ShizList"></div>
        <p class="tagline">Share the stuff you love ❤️</p>
        
        <p class="description">
            Create and share wish lists with friends and family. 
            See what your loved ones want, claim items secretly, 
            and make every gift a perfect surprise.
        </p>
        
        <div class="store-buttons">
            <a href="https://apps.apple.com/app/shizlist/id123456789" class="store-button">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                </svg>
                <div class="store-text">
                    <small>Download on the</small><br>
                    App Store
                </div>
            </a>
            <a href="https://play.google.com/store/apps/details?id=co.shizlist.app" class="store-button">
                <svg viewBox="0 0 24 24" fill="currentColor">
                    <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/>
                </svg>
                <div class="store-text">
                    <small>Get it on</small><br>
                    Google Play
                </div>
            </a>
        </div>
        
        <div class="footer">
            <a href="/support">Support</a> · <a href="/about">About</a> · <a href="/privacy">Privacy</a>
        </div>
    </div>
</body>
</html>

