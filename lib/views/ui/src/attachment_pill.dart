import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// A compact, chip-like tile for an attachment used in create/edit forms.
///
/// [onOpen] should only be provided for attachments that already exist on
/// the server (i.e. after a save) — pass null for files the user has just
/// picked but not yet uploaded, so the tile isn't tappable until it's
/// actually saved. There's no separate download action: each in-app/browser
/// viewer that [onOpen] leads to has its own way to download, and file
/// types with no viewer download automatically instead of opening.
class AttachmentPill extends StatelessWidget {
  final String name;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  const AttachmentPill({
    super.key,
    required this.name,
    this.onOpen,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.document, size: 16),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
