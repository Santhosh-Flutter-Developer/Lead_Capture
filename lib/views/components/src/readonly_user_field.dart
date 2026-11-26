import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';

/// A read-only "user" field (same look as the user dropdowns, but not
/// editable). Used for "Created By", which is filled automatically with the
/// logged-in user and must not be changed by hand.
class ReadOnlyUserField extends StatelessWidget {
  final String label;
  final List<String> names;
  final bool isRequired;

  const ReadOnlyUserField({
    super.key,
    required this.label,
    required this.names,
    this.isRequired = true,
  });

  /// Display text for an [EmployeeModel] / [AdminModel], same as the user dropdowns.
  static String labelFor(dynamic u) {
    if (u is AdminModel) return '${u.name} (Admin)';
    if (u is EmployeeModel) return '${u.name} (${u.employeeId})';
    return '';
  }

  /// The logged-in user: uid + display text. Used to auto-fill "Created By".
  static Future<({String uid, String label})> loadCurrentUser() async {
    final u = await Spdb.getUser();
    if (u.userType == UserType.admin) {
      return (uid: u.uid, label: '${u.name} (Admin)');
    }
    final e = await EmployeeService.getEmployee(uid: u.uid);
    final id = e?.employeeId ?? '';
    return (uid: u.uid, label: id.isEmpty ? u.name : '${u.name} ($id)');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: names.isEmpty
                    ? Text(
                        'Loading...',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final n in names)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(n, style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                      ),
              ),
              Icon(Iconsax.lock, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ],
    );
  }
}