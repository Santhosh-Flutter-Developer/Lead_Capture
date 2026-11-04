// Flutter imports:
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '/theme/theme.dart';

class WaitingLoading extends StatelessWidget {
  const WaitingLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LoadingAnimationWidget.progressiveDots(
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
  }
}

class ExpandedLoading extends StatelessWidget {
  const ExpandedLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: LoadingAnimationWidget.progressiveDots(
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
  }
}

void futureLoading(context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    ),
  );
}
