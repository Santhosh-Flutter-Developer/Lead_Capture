import 'package:flutter/material.dart';
import 'package:leadcapture/constants/src/enum.dart';
import '/theme/theme.dart';

class ConfirmDialog extends StatefulWidget {
  final String title;
  final String content;
  final String? successText;
  final String? cancelText;
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.successText,
    this.cancelText,
  });

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
      title: Text(widget.title, style: Theme.of(context).textTheme.bodySmall),
      content: Text(
        widget.content,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      widget.cancelText ?? "Cancel",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      widget.successText ?? "Confirm",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LeadCompletionDialog extends StatefulWidget {
  final String leadName;

  const LeadCompletionDialog({super.key, required this.leadName});

  @override
  State<LeadCompletionDialog> createState() => _LeadCompletionDialogState();
}

class _LeadCompletionDialogState extends State<LeadCompletionDialog> {
  LeadCompletionStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Complete Lead',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The lead "${widget.leadName}" is marked as completed and will be converted into a deal.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          Text(
            'Select Completion Status',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: LeadCompletionStatus.values.map((status) {
              final isSelected = _selectedStatus == status;
              return ChoiceChip(
                label: Text(status.label),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.all(12),
      actions: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, null),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _selectedStatus == null
                    ? null
                    : () {
                        Navigator.pop(context, _selectedStatus);
                      },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _selectedStatus == null
                        ? AppColors.grey300
                        : AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      'Confirm & Convert',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ConfirmDialog2 extends StatelessWidget {
  final String title;
  final String content;

  const ConfirmDialog2({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
