class EmailTemplates {
  static const String otpEmail = '''
<html>
  <body style="margin:0; padding:0; background:#f5f5f5; font-family:Arial, sans-serif;">
    <div style="
      max-width:600px;
      margin:20px auto;
      background:#ffffff;
      padding:20px 25px;
      border-radius:8px;
      border:1px solid #e0e0e0;
      box-shadow:0 1px 4px rgba(0,0,0,0.08);
      font-size:15px;
      line-height:1.6;
      color:#333;
    ">
      <p>Dear User,</p>
      <p>Your One-Time Password (OTP) for password reset is:</p>
      <h2 style="text-align:center; background:#f0f0f0; padding:10px; border-radius:6px; letter-spacing:2px;">
        {otp_code}
      </h2>
      <p>This OTP is valid for the next 10 minutes. Do not share it with anyone.</p>
      <p>Thank you,<br>Team</p>
    </div>
  </body>
</html>
''';

  static const String resetPassword = '''
<html>
  <body style="margin:0; padding:0; background:#f5f5f5; font-family:Arial, sans-serif;">
    <div style="
      max-width:600px;
      margin:20px auto;
      background:#ffffff;
      padding:20px 25px;
      border-radius:8px;
      border:1px solid #e0e0e0;
      box-shadow:0 1px 4px rgba(0,0,0,0.08);
      font-size:15px;
      line-height:1.6;
      color:#333;
    ">
      <p>Dear User,</p>
      <p>We received a request to reset your password. Click the link below:</p>
      <p>
        <a href="{reset_link}" style="
          display:inline-block;
          padding:10px 16px;
          background:#007bff;
          color:#fff;
          text-decoration:none;
          border-radius:6px;
        ">Reset Password</a>
      </p>
      <p>If this was not you, please ignore this email.</p>
      <p>Thank you,<br>Team</p>
    </div>
  </body>
</html>
''';
  static const String successResetPassword = '''
<html>
  <body style="margin:0; padding:0; background:#f5f5f5; font-family:Arial, sans-serif;">
    <div style="
      max-width:600px;
      margin:20px auto;
      background:#ffffff;
      padding:20px 25px;
      border-radius:8px;
      border:1px solid #e0e0e0;
      box-shadow:0 1px 4px rgba(0,0,0,0.08);
      font-size:15px;
      line-height:1.6;
      color:#333;
    ">
      <p>Dear User,</p>
      <p>Your password has been successfully updated.</p>
      <p>If you did not change your password, please reset it immediately.</p>
      <p>Thank you,<br>Team</p>
    </div>
  </body>
</html>
''';

  static const String loginAlert = '''
<html>
  <body style="margin:0; padding:0; background:#f5f5f5; font-family:Arial, sans-serif;">
    <div style="
      max-width:600px;
      margin:20px auto;
      background:#ffffff;
      padding:20px 25px;
      border-radius:8px;
      border:1px solid #e0e0e0;
      box-shadow:0 1px 4px rgba(0,0,0,0.08);
      font-size:15px;
      line-height:1.6;
      color:#333;
    ">
      <p>Dear User,</p>
      <p>A new login to your account was detected.</p>

      <ul style="background:#f9f9f9; padding:12px 16px; border-radius:6px; border:1px solid #eee;">
        <li><strong>IP Address:</strong> {ip_address}</li>
        <li><strong>Location:</strong> {location}</li>
        <li><strong>Date & Time:</strong> {datetime}</li>
        <li><strong>Device:</strong> {device}</li>
      </ul>

      <p>If this was you, no action is needed. If not, please secure your account immediately.</p>
      <p>Thank you,<br>Team</p>
    </div>
  </body>
</html>
''';
}
