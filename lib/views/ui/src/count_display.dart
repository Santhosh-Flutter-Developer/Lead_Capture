/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import '/theme/theme.dart';

class CountDisplay extends StatelessWidget {
  final int pageNumber;
  final int pageLimit;
  final int totalCount;

  const CountDisplay({
    super.key,
    required this.pageNumber,
    required this.pageLimit,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            text: "Total Records : ",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            children: [
              TextSpan(
                text: totalCount.toString(),
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        RichText(
          text: TextSpan(
            text: "Showing : ",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            children: [
              TextSpan(
                text: "$pageNumber / $pageLimit",
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
