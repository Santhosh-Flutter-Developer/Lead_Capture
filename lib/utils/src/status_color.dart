// Flutter imports:
import 'package:flutter/material.dart';

Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case "pending":
      return Colors.amber; // Yellow for pending
    case "rejected":
      return Colors.red; // Red for rejected
    case "approved":
      return Colors.green; // Green for accepted
    default:
      return Colors.grey; // Default color for unknown status
  }
}
