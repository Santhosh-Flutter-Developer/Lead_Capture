import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class FormWidgets {
  static PreferredSizeWidget buildHeader({
    required BuildContext context,
    required String title,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
      automaticallyImplyLeading: false,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      centerTitle: false,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  static Widget buildBottomBar({
    required BuildContext context,
    required VoidCallback onSubmit,
    bool isEdit = false,
    String cancelText = "Cancel",
    IconData cancelIcon = Icons.close_rounded,
    IconData createIcon = Icons.add_rounded,
    IconData editIcon = Iconsax.edit,
  }) {
    final submitText = isEdit ? "Update" : "Create";
    final submitIcon = isEdit ? editIcon : createIcon;
   const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Cancel Button
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                 if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cancelIcon,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cancelText,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     if (Navigator.canPop(context)) {
          //       Navigator.pop(context);
          //     }
          //   },
          //   style: ElevatedButton.styleFrom(
          //     elevation: 0,
          //     backgroundColor: Theme.of(
          //       context,
          //     ).colorScheme.surfaceContainerHighest,
          //     foregroundColor: Theme.of(context).colorScheme.onSurface,
          //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(10),
          //       side: BorderSide(
          //         color: Theme.of(context).colorScheme.outlineVariant,
          //       ),
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(cancelIcon, size: 18),
          //       const SizedBox(width: 6),
          //       Text(
          //         cancelText,
          //         style: Theme.of(
          //           context,
          //         ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          //       ),
          //     ],
          //   ),
          // ),

          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(submitIcon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          submitText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Submit Button (Create or Update)
          /*ElevatedButton(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              elevation: 2,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(submitIcon, size: 20),
                const SizedBox(width: 6),
                Text(
                  submitText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),*/
        ],
      ),
    );
  }
}
