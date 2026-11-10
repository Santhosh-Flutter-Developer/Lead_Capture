import 'package:flutter/material.dart';

/// Generic client-side e-mail sending is NOT available any more.
///
/// The old implementation POSTed to a Firebase Cloud Function and shipped
/// the SMTP username/PASSWORD inside the app binary. The PHP API has no
/// "send e-mail" endpoint (it sends OTP / reset mails itself, server-side),
/// so this now returns false without sending anything. Callers already
/// ignore the result. See MISSING_API_REQUIREMENTS.md.
class EmailService {
  static Future<bool> sendEmail({
    required List<String> to,
    required List<String> toName,
    required String subject,
    required String message,
  }) async {
    debugPrint('EmailService: "$subject" not sent – no API endpoint for client e-mails.');
    return false;
  }
}
