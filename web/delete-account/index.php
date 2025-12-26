<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Delete Account - ShizList</title>
    
    <!-- Favicon -->
    <link rel="icon" type="image/png" href="/images/app_icon.png">
    <link rel="apple-touch-icon" href="/images/app_icon.png">
    
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Source+Sans+3:wght@400;600&display=swap" rel="stylesheet">
    
    <style>
        :root {
            --primary: #009688;
            --text-primary: #212121;
            --text-secondary: #757575;
            --surface: #FFFFFF;
            --error: #D32F2F;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Source Sans 3', -apple-system, BlinkMacSystemFont, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
            min-height: 100vh;
            padding: 40px 20px;
            color: var(--text-primary);
        }
        
        .container {
            background: var(--surface);
            border-radius: 24px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.1);
            max-width: 600px;
            margin: 0 auto;
            padding: 48px;
        }
        
        .logo img {
            height: 40px;
            margin-bottom: 8px;
        }
        
        h1 {
            font-family: 'Montserrat', sans-serif;
            font-weight: 700;
            font-size: 32px;
            margin: 32px 0 24px;
            color: var(--error);
        }
        
        h2 {
            font-family: 'Montserrat', sans-serif;
            font-weight: 600;
            font-size: 20px;
            margin: 32px 0 16px;
        }
        
        p {
            font-size: 16px;
            line-height: 1.7;
            color: var(--text-primary);
            margin-bottom: 16px;
        }
        
        a { color: var(--primary); }
        
        .warning-box {
            background: #FFF3E0;
            border-left: 4px solid #FF9800;
            border-radius: 8px;
            padding: 20px;
            margin: 24px 0;
        }
        
        .warning-box p {
            margin-bottom: 0;
            color: #E65100;
        }
        
        .steps {
            background: #f5f5f5;
            border-radius: 12px;
            padding: 24px;
            margin: 24px 0;
        }
        
        .steps ol {
            margin: 0 0 0 20px;
            line-height: 2.2;
        }
        
        .steps li {
            padding-left: 8px;
        }
        
        .contact-box {
            background: #E8F5E9;
            border-radius: 12px;
            padding: 24px;
            margin-top: 32px;
        }
        
        .contact-box h3 {
            margin-bottom: 12px;
            color: var(--primary);
        }
        
        .data-list {
            margin: 16px 0 16px 24px;
            line-height: 2;
        }
        
        .back-link {
            display: inline-block;
            margin-top: 32px;
            color: var(--primary);
            text-decoration: none;
        }
        
        .back-link:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <a href="/" class="logo">
            <img src="/images/ShizList-Logo.png" alt="ShizList">
        </a>
        
        <h1>Delete Your Account</h1>
        
        <p>
            We're sorry to see you go. If you wish to delete your ShizList account, 
            please follow the instructions below.
        </p>
        
        <div class="warning-box">
            <p>
                <strong>⚠️ Warning:</strong> Account deletion is permanent and cannot be undone. 
                All your data will be permanently removed from our servers.
            </p>
        </div>
        
        <h2>What gets deleted</h2>
        <p>When you delete your account, the following data will be permanently removed:</p>
        <ul class="data-list">
            <li>Your profile information</li>
            <li>All your wish lists and items</li>
            <li>Your friends and contacts</li>
            <li>All messages and conversations</li>
            <li>Claim history and purchase records</li>
            <li>Invite links you've created</li>
        </ul>
        
        <h2>How to delete your account</h2>
        
        <div class="steps">
            <p><strong>From the ShizList app:</strong></p>
            <ol>
                <li>Open the ShizList app</li>
                <li>Tap your profile picture (top right) to open the menu</li>
                <li>Go to <strong>Settings</strong></li>
                <li>Scroll down and tap <strong>Delete Account</strong></li>
                <li>Confirm your decision when prompted</li>
            </ol>
        </div>
        
        <div class="contact-box">
            <h3>Need Help?</h3>
            <p>
                If you're unable to delete your account through the app, or if you have 
                any questions, please contact us and we'll assist you.
            </p>
            <p style="margin-bottom: 0;">
                Email: <a href="mailto:support@shizlist.co">support@shizlist.co</a>
            </p>
        </div>
        
        <p style="margin-top: 32px; color: var(--text-secondary); font-size: 14px;">
            Account deletion requests are typically processed within 24-48 hours. 
            You will receive an email confirmation once your account has been deleted.
        </p>
        
        <a href="/" class="back-link">← Back to home</a>
    </div>
</body>
</html>

