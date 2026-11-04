/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/material.dart';
class Sheet {
  static Future<dynamic> showSheet(BuildContext context,
      {required Widget widget, double size = 0.9}) async {
    final value = await showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.surface,
      useSafeArea: true,
      showDragHandle: false,
      isScrollControlled: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        side: BorderSide.none,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      context: context,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 500),
      ),
      builder: (BuildContext builderContext) {
        return FractionallySizedBox(heightFactor: size, child: widget);
      },
    );
    return value;
  }
}
