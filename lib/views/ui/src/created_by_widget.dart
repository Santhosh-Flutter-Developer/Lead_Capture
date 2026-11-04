import 'package:flutter/material.dart';
import '/models/models.dart';
import '/views/views.dart';

class CreatedByWidget extends StatelessWidget {
  final UserDataModel userData;
  const CreatedByWidget({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(userData: userData),
        SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userData.name.isNotEmpty ? userData.name : '',
              style: Theme.of(
                context,
              ).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold),
            ),
            // Text(
            //   userData.desc ?? '',
            //   style: Theme.of(context).textTheme.bodySmall,
            // ),
          ],
        ),
      ],
    );
  }
}
