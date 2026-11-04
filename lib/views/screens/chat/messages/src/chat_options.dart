part of 'chat_messages.dart';

class ChatOptions extends StatelessWidget {
  final bool edit, delete;
  const ChatOptions({super.key, this.delete = false, this.edit = false});

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color accentColor,
    required int result,
  }) {
    return ListTile(
      onTap: () => Navigator.pop(context, result),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: accentColor),
      ),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: ListView(
          primary: false,
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (edit)
              _tile(
                context,
                icon: Iconsax.edit,
                label: "Edit",
                accentColor: Theme.of(context).colorScheme.primary,
                result: 1,
              ),
            if (delete)
              _tile(
                context,
                icon: Iconsax.trash,
                label: "Delete",
                accentColor: Theme.of(context).colorScheme.error,
                result: 2,
              ),
            if (edit || delete)
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
            _tile(
              context,
              icon: Icons.reply_rounded,
              label: "Quote in reply",
              accentColor: Theme.of(context).colorScheme.secondary,
              result: 3,
            ),
            _tile(
              context,
              icon: Iconsax.send_2,
              label: "Forward",
              accentColor: Theme.of(context).colorScheme.primary,
              result: 5,
            ),
            _tile(
              context,
              icon: Iconsax.copy,
              label: "Copy Text",
              accentColor: Theme.of(context).colorScheme.onSurfaceVariant,
              result: 4,
            ),
          ],
        ),
      ),
    );
  }
}