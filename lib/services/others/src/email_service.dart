import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/services/services.dart';

class EmailService {
  static Future<bool> sendEmail({
    required List<String> to,
    required List<String> toName,
    required String subject,
    required String message,
  }) async {
    try {
      var response = await http.post(
        Uri.parse(
          "https://us-central1-leadcapture-79a43.cloudfunctions.net/sendEmail",
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "smtp_host": "smtp.gmail.com",
          "smtp_user": "systemadmin@srisoftwarez.com",
          "smtp_pass": "mxlfsavbqgrbhmrq",
          "from": "systemadmin@srisoftwarez.com",
          "from_name": "LeadcaptureCRM",
          "to": to.map((e) => e.trim()).toList().join(','),
          "to_name": toName.map((e) => e.trim()).toList().join(','),
          "reply_to": "systemadmin@srisoftwarez.com",
          "subject": subject,
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          "Failed to send email. Status code: ${response.statusCode}, Body: ${response.body}",
        );
        return false;
      }
    } catch (e, st) {
      debugPrint("Error resetting password: $e, $st");
      await ErrorService.recordError(e, st);
      return false;
    }
  }
}
