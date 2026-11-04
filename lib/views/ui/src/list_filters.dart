import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/utils.dart';

/// uid->name  ==>  name->uid, sorted A-Z, for the searchable filter dropdowns
/// (which work with plain strings). Two people with the same name get a "(2)"
/// suffix so picking one can never silently match the other.
Map<String, String> nameToUidOptions(Map<String, String> uidToName) {
  final entries = uidToName.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
  final out = <String, String>{};
  for (final e in entries) {
    var label = e.value;
    var n = 2;
    while (out.containsKey(label)) {
      label = '${e.value} ($n)';
      n++;
    }
    out[label] = e.key;
  }
  return out;
}

/// Whether [d] falls inside [range], counting the whole end day.
/// A null [d] never matches.
bool dateInRange(DateTime? d, DateTimeRange range) {
  if (d == null) return false;
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final endExclusive = DateTime(
    range.end.year,
    range.end.month,
    range.end.day + 1,
  );
  return !d.isBefore(start) && d.isBefore(endExclusive);
}

/// Card used by list screens to host their filter fields: a "Filters (n
/// applied)" header with a "Clear filters" button and the [fields] laid out in
/// 4 / 2 / 1 columns depending on the available width.
class ListFilterCard extends StatelessWidget {
  final List<Widget> fields;
  final int activeCount;
  final VoidCallback onClear;

  const ListFilterCard({
    super.key,
    required this.fields,
    required this.activeCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActive = activeCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
          const gap = 12.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Iconsax.filter, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    hasActive ? 'Filters ($activeCount applied)' : 'Filters',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: hasActive ? onClear : null,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear filters'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: gap,
                runSpacing: 12,
                children: [for (final f in fields) SizedBox(width: w, child: f)],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Date-range filter field. Looks like the other filter dropdowns (label on
/// top, 33px outlined box) but opens a date-range picker via [onTap].
class DateRangeFilterField extends StatelessWidget {
  final String label;
  final DateTimeRange? range;
  final VoidCallback onTap;
  final VoidCallback onClear;

  /// Optional widget shown at the right end of the label row (e.g. a "which
  /// date?" selector).
  final Widget? labelTrailing;

  const DateRangeFilterField({
    super.key,
    required this.label,
    required this.range,
    required this.onTap,
    required this.onClear,
    this.labelTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = range;
    final String text;
    if (r == null) {
      text = 'Select range';
    } else if (r.start == r.end) {
      text = r.start.formatDateMonth;
    } else {
      text = '${r.start.formatDateMonth} - ${r.end.formatDateMonth}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (labelTrailing != null) labelTrailing!,
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: r != null
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (r != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(Icons.clear, size: 16, color: Colors.grey),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  Iconsax.calendar_1,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}