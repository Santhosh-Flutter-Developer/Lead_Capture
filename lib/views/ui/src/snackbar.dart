// Flutter imports:
import 'package:flutter/material.dart';
// Package imports:
import 'package:iconsax/iconsax.dart';
import '/theme/theme.dart';
import '/app/app.dart';

class Snackbar {
  static void showSnackBar(
    BuildContext context, {
    required String content,
    bool isSuccess = true,
  }) {
    ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating, // Makes it float
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ), // Adjust margin
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ), // Rounded corners
        content: Row(
          children: [
            Icon(
              isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
              color: AppColors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content,
                overflow: TextOverflow.visible,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.danger,
      ),
    );
  }

  static void showSnackBarOption(
    context, {
    required String content,
    required bool isSuccess,
    required String actionText,
    required VoidCallback action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Row(
          children: [
            Icon(
              isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
              color: AppColors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content,
                overflow: TextOverflow.visible,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.danger,
        action: SnackBarAction(
          label: actionText,
          textColor: AppColors.white,
          onPressed: action,
        ),
      ),
    );
  }
}
