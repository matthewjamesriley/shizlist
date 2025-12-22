<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About - ShizList</title>
    
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
            font-size: 32px;
            margin: 32px 0 24px;
        }
        
        p {
            font-size: 16px;
            line-height: 1.7;
            color: var(--text-primary);
            margin-bottom: 16px;
        }
        
        a { color: var(--primary); }
        
        .features {
            margin: 32px 0;
        }
        
        .feature {
            display: flex;
            gap: 16px;
            margin-bottom: 20px;
        }
        
        .feature-icon {
            font-size: 24px;
        }
        
        .feature h3 {
            font-size: 18px;
            margin-bottom: 4px;
        }
        
        .feature p {
            margin: 0;
            font-size: 14px;
            color: var(--text-secondary);
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
        
        <h1>About ShizList</h1>
        
        <p>
            ShizList is the easiest way to create and share wish lists with 
            friends and family. Whether it's for birthdays, holidays, weddings, 
            or just keeping track of things you want – ShizList makes it simple.
        </p>
        
        <div class="features">
            <div class="feature">
                <div class="feature-icon">📝</div>
                <div>
                    <h3>Create Multiple Lists</h3>
                    <p>Organize your wishes by occasion – birthdays, Christmas, baby showers, and more.</p>
                </div>
            </div>
            
            <div class="feature">
                <div class="feature-icon">🔗</div>
                <div>
                    <h3>Easy Sharing</h3>
                    <p>Share lists with a simple link or QR code. No account needed to view.</p>
                </div>
            </div>
            
            <div class="feature">
                <div class="feature-icon">🎁</div>
                <div>
                    <h3>Secret Claiming</h3>
                    <p>Claim items without the list owner knowing – perfect for surprise gifts!</p>
                </div>
            </div>
            
            <div class="feature">
                <div class="feature-icon">🛒</div>
                <div>
                    <h3>Amazon Integration</h3>
                    <p>Add items directly from Amazon with one tap.</p>
                </div>
            </div>
        </div>
        
        <p>
            <strong>Share the stuff you love.</strong>
        </p>
        
        <a href="/" class="back-link">← Back to home</a>
    </div>
</body>
</html>

