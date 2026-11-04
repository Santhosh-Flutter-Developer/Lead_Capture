/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

// Flutter imports:
import 'package:flutter/cupertino.dart';

void route(BuildContext context, Widget widget) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) {
        return widget;
      },
    ),
  );
}
