import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

Future<Color?> pickColor(BuildContext context, Color selectedColor) async {
  Color? pickedColor = selectedColor;

  return await showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Pick a Color', style: Theme.of(context).textTheme.bodySmall),
      content: BlockPicker(
        pickerColor: selectedColor,
        onColorChanged: (color) {
          pickedColor = color;
        },
      ),
      actions: [
        TextButton(
          child: Text('CANCEL', style: Theme.of(context).textTheme.bodySmall),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        TextButton(
          child: Text('SELECT', style: Theme.of(context).textTheme.bodySmall),
          onPressed: () {
            Navigator.of(context).pop(pickedColor);
          },
        ),
      ],
    ),
  );
}
