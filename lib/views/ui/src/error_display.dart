import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/utils/utils.dart';

class ErrorDisplay extends StatelessWidget {
  final String error;
  const ErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(SvgAssets.error, height: 80, width: 80),
            Text(
              "Error",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class NoData extends StatelessWidget {
  final Color? bgColor;
  final String? text;
  const NoData({super.key, this.bgColor, this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: bgColor == null
              ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SvgPicture.asset(SvgAssets.emptyBox, height: 80, width: 80),
            Text(
              "No records",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            SelectableText(
              text ?? "No data available to show",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
