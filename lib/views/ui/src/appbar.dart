/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:

class Appbar extends StatelessWidget implements PreferredSizeWidget {
  final bool searchApplied;
  final TextEditingController search;
  final VoidCallback backPress;
  final ValueChanged<String>? onChanged;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? nonSearchTitle;
  final String searchHintText;
  final Color? backgroundColor;

  const Appbar({
    super.key,
    required this.searchApplied,
    required this.search,
    required this.backPress,
    this.onChanged,
    this.actions,
    this.leading,
    this.nonSearchTitle,
    this.searchHintText = "Search here",
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final slideAnimation = Tween<Offset>(
          begin: child.key == const ValueKey("searchAppBar")
              ? const Offset(-1.0, 0.0)
              : const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(position: slideAnimation, child: child);
      },
      child: searchApplied
          ? AppBar(
              key: const ValueKey("searchAppBar"),
              backgroundColor:
                  backgroundColor ?? Theme.of(context).primaryColor,
              shadowColor: Theme.of(context).shadowColor,
              leading: IconButton(
                tooltip: "Back",
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: backPress,
              ),
              title: TextFormField(
                controller: search,
                autofocus: true,
                cursorColor: Theme.of(context).colorScheme.onPrimary,
                onChanged: onChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: searchHintText,
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.6),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                autocorrect: false,
                enableSuggestions: false,
              ),
            )
          : AppBar(
              key: const ValueKey("mainAppBar"),
              backgroundColor:
                  backgroundColor ?? Theme.of(context).primaryColor,
              leading: leading ?? const SizedBox.shrink(),
              title: nonSearchTitle ?? const SizedBox.shrink(),
              actions: actions,
            ),
    );
  }
}
