/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:iconsax/iconsax.dart';

class Button extends StatelessWidget {
  final VoidCallback? event;
  final Future<void> Function()? onPressed;
  final String text;
  final double? width;
  final double? height;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;

  const Button({
    super.key,
    this.event,
    this.onPressed,
    required this.text,
    this.width,
    this.height,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          backgroundColor ?? Theme.of(context).colorScheme.primary,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: WidgetStateProperty.all(Size(height ?? 80, width ?? 40)),
        padding: WidgetStateProperty.all(const EdgeInsets.all(8)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      onPressed: event,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon ?? Iconsax.tick_circle,
            color: iconColor ?? Theme.of(context).colorScheme.onPrimary,
            size: 20,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: textColor ?? Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
