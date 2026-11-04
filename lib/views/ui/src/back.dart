import 'package:flutter/material.dart';
import '/views/views.dart';

class Back extends StatelessWidget {
  final bool pop;
  final Color? color;
  const Back({super.key, this.pop = false, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Back",
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: () async {
        if (pop) {
          var result = await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return ConfirmDialog(
                title: 'Exit',
                content: 'Are you sure want to exit?',
              );
            },
          );
          if (result != null && result) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        } else {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      },
    );
  }
}
