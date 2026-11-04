import 'package:flutter/material.dart';
import '/theme/theme.dart';

class GeneralDialog {
  static Future<dynamic> showRTLSheet(
    BuildContext context,
    Widget child,
  ) async {
    return showGeneralDialog(
      context: context,
      barrierLabel: '',
      barrierColor: AppColors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final double screenWidth = MediaQuery.of(context).size.width;
        // Below this width, the 80%/20% split leaves too little room for
        // the floating close button (it was overlapping/getting clipped by
        // the panel on narrow browser windows). Go full-width instead - the
        // panel's own AppBar already provides a back button to dismiss.
        final bool isNarrow = screenWidth < 700;
        final double panelWidth = isNarrow ? screenWidth : screenWidth * 0.8;

        return Stack(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: isNarrow
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: panelWidth,
                  height: MediaQuery.of(context).size.height,
                  child: child,
                ),
              ),
            ),
            if (!isNarrow)
              Positioned(
                top: 10,
                right: panelWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return SlideTransition(position: slide, child: child);
      },
    );
  }
}