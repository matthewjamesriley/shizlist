<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Support - ShizList</title>
    
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
        
        .contact-box {
            background: #f5f5f5;
            border-radius: 12px;
            padding: 24px;
            margin-top: 32px;
        }
        
        .contact-box h3 {
            margin-bottom: 12px;
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
        
        <h1>Help & support</h1>
        
        <p>
            Need help with ShizList? We're here to assist you with any questions 
            or issues you might have.
        </p>
        
        <p>
            <strong>Common questions:</strong>
        </p>
        
        <ul style="margin: 16px 0 16px 24px; line-height: 2;">
            <li>How do I create a new list?</li>
            <li>How do I share my list with friends?</li>
            <li>How do I claim an item on someone's list?</li>
            <li>How do I add items from Amazon?</li>
        </ul>
        
        <div class="contact-box">
            <h3>Contact Us</h3>
            <p style="margin-bottom: 0;">
                Email: <a href="mailto:support@shizlist.co">support@shizlist.co</a>
            </p>
        </div>
        
        <a href="/" class="back-link">← Back to home</a>
    </div>
</body>
</html>

