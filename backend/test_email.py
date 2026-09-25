# test_email.py
import os
import sys
from flask import Flask
from flask_mail import Mail, Message
from dotenv import load_dotenv

# Load .env variables
load_dotenv()

app = Flask(__name__)

# Configure Flask-Mail
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER', 'smtp.gmail.com')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT', 587))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS', 'true').lower() == 'true'
app.config['MAIL_USE_SSL'] = os.getenv('MAIL_USE_SSL', 'false').lower() == 'true'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_DEFAULT_SENDER')

mail = Mail(app)

def send_test_email(recipient_email=None):
    """
    Send a test email to verify email configuration.
    
    Args:
        recipient_email: Optional email to send to. If None, uses MAIL_DEFAULT_SENDER.
    """
    with app.app_context():
        # Validate configuration
        errors = []
        
        if not app.config['MAIL_USERNAME']:
            errors.append("❌ MAIL_USERNAME is not set in .env file")
        if not app.config['MAIL_PASSWORD']:
            errors.append("❌ MAIL_PASSWORD is not set in .env file")
        if not app.config['MAIL_DEFAULT_SENDER']:
            errors.append("❌ MAIL_DEFAULT_SENDER is not set in .env file")
        
        if errors:
            print("\n⚠️  Email Configuration Errors:")
            for error in errors:
                print(f"  {error}")
            print("\nPlease configure your .env file with:")
            print("  MAIL_USERNAME=your-email@gmail.com")
            print("  MAIL_PASSWORD=your-app-password")
            print("  MAIL_DEFAULT_SENDER=your-email@gmail.com")
            return False
        
        # Use provided recipient or default sender
        recipient = recipient_email or app.config['MAIL_DEFAULT_SENDER']
        
        print(f"\n📧 Sending test email to: {recipient}")
        print(f"   From: {app.config['MAIL_DEFAULT_SENDER']}")
        print(f"   Server: {app.config['MAIL_SERVER']}:{app.config['MAIL_PORT']}")
        print(f"   TLS: {app.config['MAIL_USE_TLS']}")
        print(f"   Username: {app.config['MAIL_USERNAME']}")
        
        try:
            msg = Message(
                subject="✅ Test Email from Smart Medical Hub",
                recipients=[recipient],
                sender=app.config['MAIL_DEFAULT_SENDER'],
                body="""
Hello!

This is a test email from the Smart Medical Hub application.

If you received this email, your email configuration is working properly!

Test Details:
- Time: {timestamp}
- Server: {server}:{port}
- TLS: {tls}

Best regards,
Smart Medical Hub Team
                """.format(
                    timestamp=__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    server=app.config['MAIL_SERVER'],
                    port=app.config['MAIL_PORT'],
                    tls=app.config['MAIL_USE_TLS']
                ),
                html="""
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #4A90D9, #27AE60); color: white; padding: 20px; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 20px; border-radius: 0 0 10px 10px; }
        .footer { text-align: center; margin-top: 20px; font-size: 12px; color: #999; }
        .success { color: #27AE60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 style="margin: 0;">🏥 Smart Medical Hub</h1>
            <p style="margin: 5px 0 0 0;">Email Test</p>
        </div>
        <div class="content">
            <h2>✅ Email Configuration Test</h2>
            <p>Hello!</p>
            <p>This is a test email from the <strong>Smart Medical Hub</strong> application.</p>
            <p>If you received this email, your email configuration is <span class="success">working properly!</span></p>
            
            <hr>
            
            <h3>📋 Test Details:</h3>
            <ul>
                <li><strong>Time:</strong> {timestamp}</li>
                <li><strong>Server:</strong> {server}:{port}</li>
                <li><strong>TLS:</strong> {tls}</li>
            </ul>
            
            <p style="margin-top: 20px; color: #666;">Best regards,<br><strong>Smart Medical Hub Team</strong></p>
        </div>
        <div class="footer">
            <p>This is an automated test email. Please do not reply to this message.</p>
            <p>&copy; 2024 Smart Medical Hub. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
                """
            )
            
            mail.send(msg)
            print("\n✅ Test email sent successfully!")
            print(f"   Please check {recipient} inbox (and spam folder) for the email.")
            return True
            
        except Exception as e:
            print(f"\n❌ Failed to send test email: {str(e)}")
            print("\nPossible issues:")
            print("  1. Wrong email/password in .env file")
            print("  2. Less secure app access not enabled for Gmail")
            print("  3. Network connectivity issues")
            print("  4. SMTP server settings are incorrect")
            print("\nFor Gmail, you need to:")
            print("  1. Enable 2-Factor Authentication")
            print("  2. Generate an App Password (not your regular password)")
            print("  3. Use the App Password in MAIL_PASSWORD")
            return False

def check_env_file():
    """Check if .env file exists and has required variables."""
    env_file = '.env'
    if not os.path.exists(env_file):
        print(f"⚠️  {env_file} file not found!")
        print("\nPlease create a .env file with the following content:")
        print("  MAIL_SERVER=smtp.gmail.com")
        print("  MAIL_PORT=587")
        print("  MAIL_USE_TLS=true")
        print("  MAIL_USERNAME=your-email@gmail.com")
        print("  MAIL_PASSWORD=your-app-password")
        print("  MAIL_DEFAULT_SENDER=your-email@gmail.com")
        return False
    
    print(f"✅ {env_file} file found.")
    
    # Check required variables
    required_vars = ['MAIL_USERNAME', 'MAIL_PASSWORD', 'MAIL_DEFAULT_SENDER']
    missing_vars = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"⚠️  Missing required variables in .env: {', '.join(missing_vars)}")
        return False
    
    return True

if __name__ == "__main__":
    print("=" * 60)
    print("🔧 Smart Medical Hub - Email Configuration Test")
    print("=" * 60)
    
    # Check .env file
    if not check_env_file():
        sys.exit(1)
    
    print("\n📧 Testing email configuration...")
    
    # Parse command line arguments
    recipient = None
    if len(sys.argv) > 1:
        recipient = sys.argv[1]
        print(f"📨 Sending to custom recipient: {recipient}")
    else:
        print(f"📨 Sending to default sender: {os.getenv('MAIL_DEFAULT_SENDER')}")
        print("   (To send to a different email, run: python test_email.py recipient@example.com)")
    
    print("-" * 60)
    
    # Send test email
    success = send_test_email(recipient)
    
    print("-" * 60)
    if success:
        print("🎉 Email test completed successfully!")
    else:
        print("❌ Email test failed. Please check the errors above.")
        sys.exit(1)