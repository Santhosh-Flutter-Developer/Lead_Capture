/*
  Copyright 2024 Srisoftwarez. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

import 'package:flutter/material.dart';
import '/theme/theme.dart';

class InstallInfo extends StatefulWidget {
  const InstallInfo({super.key});

  @override
  State<InstallInfo> createState() => _InstallInfoState();
}

class _InstallInfoState extends State<InstallInfo> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Update Instructions",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "1. You cannot access the app without the latest version.\n"
                "2. If a new version is available, click the Update button on the update screen.\n"
                "3. Once the download is complete, you will see the Install button.\n"
                "4. Click it and enable the \"Install Unknown Apps\" option in the settings.\n"
                "5. You must enable this option on Android to install the app.\n"
                "6. After enabling it, click Update in the alert box.\n"
                "7. Install the app and enjoy using it.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
