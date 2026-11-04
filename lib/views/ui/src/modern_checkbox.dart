import 'package:flutter/material.dart';

class ModernCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  const ModernCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? theme.colorScheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: 1.6,
              ),
            ),
            child: AnimatedScale(
              scale: value ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),

          if (label != null) ...[
            const SizedBox(width: 10),
            Text(label!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
