import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/theme/theme.dart';

/// Shared look of the Expense screens (banner, stat boxes, chips, search,
/// cancellation-remarks dialog) so Category / Listing / Report stay in sync.
final NumberFormat expenseMoney =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

const List<Color> expenseGradient = [
  Color(0xFF0052D4),
  Color(0xFF4364F7),
  Color(0xFF6FB1FC),
];

/// Gradient header card shown on wide screens.
class ExpenseBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> trailing;
  const ExpenseBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: expenseGradient,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052D4).withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          for (final w in trailing) ...[const SizedBox(width: 12), w],
        ],
      ),
    );
  }
}

/// Small translucent stat box used inside the banner / on mobile.
class ExpenseStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? tint;
  final bool onLight;
  const ExpenseStatBox({
    super.key,
    required this.label,
    required this.value,
    this.tint,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fg = onLight ? (tint ?? scheme.primary) : AppColors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: onLight
            ? (tint ?? scheme.primary).withValues(alpha: 0.08)
            : (tint ?? AppColors.white).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: t.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: t.labelSmall?.copyWith(
              color: fg.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

Widget expenseChip(String text, Color color, {IconData? icon}) {
  if (text.trim().isEmpty) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    ),
  );
}

/// Bordered surface card.
Widget expenseCard(BuildContext context, Widget child, {EdgeInsets? padding}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

/// Round icon button used in table action columns.
Widget expenseIconButton(
  BuildContext context, {
  required IconData icon,
  required String tooltip,
  required Color color,
  required VoidCallback onPressed,
}) {
  return Tooltip(
    message: tooltip,
    child: Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    ),
  );
}

Widget expenseGradientButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  List<Color> colors = expenseGradient,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: colors.first.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Search box with a clear button.
class ExpenseSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const ExpenseSearchField({super.key, required this.hint, required this.onChanged});

  @override
  State<ExpenseSearchField> createState() => _ExpenseSearchFieldState();
}

class _ExpenseSearchFieldState extends State<ExpenseSearchField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      style: Theme.of(context).textTheme.bodySmall,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  _c.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Asks for the (mandatory) cancellation remarks. Returns null when dismissed.
Future<String?> askCancellationRemarks(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RemarksDialog(title: title, message: message),
  );
}

class _RemarksDialog extends StatefulWidget {
  final String title;
  final String message;
  const _RemarksDialog({required this.title, required this.message});

  @override
  State<_RemarksDialog> createState() => _RemarksDialogState();
}

class _RemarksDialogState extends State<_RemarksDialog> {
  final _c = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message, style: t.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Cancellation remarks *',
                  hintText: 'Why is this expense being cancelled?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '* Remarks are required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Expense'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            if (_key.currentState!.validate()) Navigator.pop(context, _c.text.trim());
          },
          child: const Text('Cancel Expense'),
        ),
      ],
    );
  }
}