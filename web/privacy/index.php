<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - ShizList</title>
    
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
            max-width: 700px;
            margin: 0 auto;
            padding: 48px;
        }
        
        .logo img {
            height: 40px;
            margin-bottom: 8px;
        }
        
        h1 {
            font-size: 32px;
            margin: 32px 0 8px;
        }
        
        .last-updated {
            font-size: 14px;
            color: var(--text-secondary);
            margin-bottom: 24px;
        }
        
        h2 {
            font-size: 20px;
            margin: 32px 0 12px;
            color: var(--text-primary);
        }
        
        p {
            font-size: 16px;
            line-height: 1.7;
            color: var(--text-primary);
            margin-bottom: 16px;
        }
        
        ul {
            margin: 12px 0 16px 24px;
            line-height: 1.8;
        }
        
        li {
            margin-bottom: 8px;
        }
        
        a { color: var(--primary); }
        
        .highlight-box {
            background: #e8f5f3;
            border-left: 4px solid var(--primary);
            border-radius: 8px;
            padding: 16px 20px;
            margin: 24px 0;
        }
        
        .highlight-box p {
            margin: 0;
        }
        
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
        
        <h1>Privacy Policy</h1>
        <p class="last-updated">Last updated: <?php echo date('F j, Y'); ?></p>
        
        <div class="highlight-box">
            <p><strong>In short:</strong> We collect only what's necessary to make ShizList work. We don't sell your data, and we take your privacy seriously.</p>
        </div>
        
        <h2>Information We Collect</h2>
        <p>When you use ShizList, we collect:</p>
        <ul>
            <li><strong>Account information:</strong> Your email address and display name when you sign up</li>
            <li><strong>List data:</strong> The wish lists and items you create</li>
            <li><strong>Profile photo:</strong> If you choose to add one</li>
            <li><strong>Usage data:</strong> Basic analytics to help us improve the app</li>
        </ul>
        
        <h2>How We Use Your Information</h2>
        <p>We use your information to:</p>
        <ul>
            <li>Provide and maintain the ShizList service</li>
            <li>Allow you to share lists with friends and family</li>
            <li>Send you important updates about your account</li>
            <li>Improve and optimize the app experience</li>
        </ul>
        
        <h2>Information Sharing</h2>
        <p>We share your information only in the following ways:</p>
        <ul>
            <li><strong>With people you choose:</strong> When you share a list, recipients can see the list contents and your display name</li>
            <li><strong>Service providers:</strong> We use trusted third parties (like Supabase for our database) to operate our service</li>
            <li><strong>Legal requirements:</strong> If required by law or to protect our rights</li>
        </ul>
        <p><strong>We do not sell your personal information to third parties.</strong></p>
        
        <h2>Data Security</h2>
        <p>We implement appropriate security measures to protect your personal information, including:</p>
        <ul>
            <li>Encrypted data transmission (HTTPS)</li>
            <li>Secure authentication via email verification</li>
            <li>Regular security reviews</li>
        </ul>
        
        <h2>Your Rights</h2>
        <p>You have the right to:</p>
        <ul>
            <li>Access your personal data</li>
            <li>Correct inaccurate data</li>
            <li>Delete your account and associated data</li>
            <li>Export your data</li>
        </ul>
        
        <h2>Third-Party Services</h2>
        <p>ShizList may contain links to Amazon and other retailers. When you click these links, you'll be subject to their privacy policies. We use Amazon's affiliate program, which means we may earn a small commission on purchases made through our links.</p>
        
        <h2>Children's Privacy</h2>
        <p>ShizList is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us immediately.</p>
        
        <h2>Changes to This Policy</h2>
        <p>We may update this privacy policy from time to time. We'll notify you of any significant changes by posting the new policy on this page and updating the "Last updated" date.</p>
        
        <div class="contact-box">
            <h3>Questions?</h3>
            <p style="margin-bottom: 0;">
                If you have any questions about this privacy policy, please contact us at:<br>
                <a href="mailto:privacy@shizlist.co">privacy@shizlist.co</a>
            </p>
        </div>
        
        <a href="/" class="back-link">← Back to home</a>
    </div>
</body>
</html>

