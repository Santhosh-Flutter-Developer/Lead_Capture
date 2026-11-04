import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/theme/theme.dart';
import '/utils/utils.dart';

// keep your kIsMobile definition or replace with your own check if needed
// const bool kIsMobile = false;

class PaginationControls<T> extends StatelessWidget {
  const PaginationControls({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Listen to the controller to rebuild when pagination state changes
    final controller = context.watch<PaginatedDataController<T>>();

    // Use controllerRead for methods so we don't rebuild unnecessarily
    final controllerRead = context.read<PaginatedDataController<T>>();

    final int totalEntries = controller.totalEntries;
    final int totalPages = controller.totalPages;
    final int startEntry = controller.startEntry;
    final int endEntry = controller.endEntry;

    return LayoutBuilder(
      builder: (context, constraints) {
        final entriesDropdown = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Show",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
            ),
            const SizedBox(width: 8),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: controller.rowsPerPage,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: [10, 25, 50].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(
                        value.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }).toList(),
                  onChanged: controllerRead.setRowsPerPage,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "entries",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
            ),
          ],
        );

        final showingText = Text(
          "Showing $startEntry to $endEntry of $totalEntries entries",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.grey),
        );

        // NEW: page selection as dropdown (compact, not container-format buttons)
        final pageDropdown = _pageDropdown(context, totalPages);

        final paginationControls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: controller.currentPage > 1
                  ? controllerRead.previousPage
                  : null,
              child: Text(
                "Previous",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),

            // use dropdown instead of many page buttons
            pageDropdown,

            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: controller.currentPage < totalPages
                  ? controllerRead.nextPage
                  : null,
              child: Text("Next", style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        );

        return kIsMobile || width < 1000
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  entriesDropdown,
                  const SizedBox(height: 8),
                  showingText,
                  const SizedBox(height: 8),
                  paginationControls,
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [entriesDropdown, showingText, paginationControls],
              );
      },
    );
  }

  /// Returns a compact dropdown for page selection
  Widget _pageDropdown(BuildContext context, int totalPages) {
    final controller = context.watch<PaginatedDataController<T>>();
    final controllerRead = context.read<PaginatedDataController<T>>();

    // If there is only 1 page, show simple label
    if (totalPages <= 1) {
      return Text(
        "Page 1 of 1",
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.grey700),
      );
    }

    // Build list of DropdownMenuItem<int> — keep them simple (no extra container)
    final items = List<DropdownMenuItem<int>>.generate(totalPages, (i) {
      final pageNumber = i + 1;
      return DropdownMenuItem<int>(
        value: pageNumber,
        child: Text(
          pageNumber.toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    });

    // Use a minimal DropdownButton (no underline)
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: controller.currentPage,
          icon: const Icon(Icons.arrow_drop_down),
          items: items,

          onChanged: (value) {
            if (value != null) controllerRead.goToPage(value);
          },
        ),
      ),
    );
  }
}
