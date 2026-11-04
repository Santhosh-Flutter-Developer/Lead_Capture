import 'package:flutter/material.dart';

Widget buildNoPermissionView(BuildContext context) {
  return Center(
    child: Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: Colors.redAccent),
          SizedBox(height: 12),
          Text(
            "Access Denied",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "You don't have permission to access this resource.",
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
