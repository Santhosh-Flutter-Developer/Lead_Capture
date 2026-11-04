import 'package:flutter/material.dart';
import '/theme/theme.dart';

class ErrorScreen extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, this.error, this.stackTrace, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.white),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Text(
                      "ERROR OCCURRED",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: AppColors.white24, thickness: 1),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ?? "Unknown error",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontFamily: 'monospace',
                  ),
                ),
                if (stackTrace != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "> Stack Trace:",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: AppColors.grey900,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        stackTrace.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.white70,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, color: AppColors.white),
                      label: Text(
                        "Retry",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white,
                          fontFamily: 'monospace',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.white38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
