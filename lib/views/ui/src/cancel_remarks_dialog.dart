import 'package:flutter/material.dart';

/// "Cancel Task" / "Cancel Ticket" dialog. Deleting a task or ticket is a
/// cancellation that needs remarks. Returns the trimmed remarks, or null when
/// the user dismissed the dialog.
Future<String?> showCancelRemarksDialog(
  BuildContext context, {
  required String entity, // 'task' | 'ticket'
  int count = 1,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CancelRemarksDialog(entity: entity, count: count),
  );
}

class _CancelRemarksDialog extends StatefulWidget {
  final String entity;
  final int count;
  const _CancelRemarksDialog({required this.entity, required this.count});

  @override
  State<_CancelRemarksDialog> createState() => _CancelRemarksDialogState();
}

class _CancelRemarksDialogState extends State<_CancelRemarksDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final E = '${e[0].toUpperCase()}${e.substring(1)}';
    final many = widget.count > 1;
    const red = Color(0xFFDC2626);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: red,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        many ? 'Cancel ${widget.count} ${E}s' : 'Cancel $E',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        many
                            ? 'Are you sure you want to cancel the selected ${e}s? Once cancelled, their status cannot be changed, they will display as CANCEL below the $e number, and they cannot be deleted again.'
                            : 'Are you sure you want to cancel this $e? Once cancelled, its status cannot be changed, it will display as CANCEL below $e number, and it cannot be deleted again.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ctrl,
                        minLines: 3,
                        maxLines: 5,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Cancellation Remarks / Reason *',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Remarks are required'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: red),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.of(context).pop(_ctrl.text.trim());
                        }
                      },
                      child: const Text('Confirm Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}