import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '/theme/theme.dart';

class PickOption extends StatelessWidget {
  final bool uploadDoc;
  const PickOption({super.key, this.uploadDoc = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 15, bottom: 15, right: 15),
        child: ListView(
          primary: false,
          shrinkWrap: true,
          children: [
            ListTile(
              onTap: () => Navigator.pop(context, 1),
              title: Text(
                "Camera",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.black),
              ),
              leading: const Icon(Iconsax.camera),
            ),
            ListTile(
              onTap: () => Navigator.pop(context, 2),
              title: Text(
                "Gallery",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.black),
              ),
              leading: const Icon(Iconsax.gallery),
            ),
            if (uploadDoc)
              ListTile(
                onTap: () => Navigator.pop(context, 3),
                title: Text(
                  "Document",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.black),
                ),
                leading: const Icon(Iconsax.gallery),
              ),
          ],
        ),
      ),
    );
  }
}
