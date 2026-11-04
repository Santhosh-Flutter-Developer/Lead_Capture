import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:leadcapture/views/screens/creations/roles/listing/role_permission_table.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class RoleCreate extends StatefulWidget {
  const RoleCreate({super.key});

  @override
  State<RoleCreate> createState() => _RoleCreateState();
}

class _RoleCreateState extends State<RoleCreate> {
  final TextEditingController _roleNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  List<PermissionModel> _rows = [];

  @override
  void initState() {
    super.initState();
    _rows = AppStrings.accessPagesList
        .map((page) => PermissionModel(page: page))
        .toList();
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isEdit: false),
            Expanded(
              child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                  
                child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      interactive: true,
                      trackVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 8,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        _sectionCard(
                          context,
                          icon: Iconsax.info_circle,
                          title: "Role Information",
                          subtitle: "Give this role a clear name and description",
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildFormFields(constraints),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionCard(
                          context,
                          icon: Iconsax.security_safe,
                          title: "Permissions",
                          subtitle:
                              "Choose what this role can view, create, edit or delete on each page",
                          child: RolePermissionTable(rows: _rows),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: false,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isEdit}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isEdit ? Iconsax.edit : Iconsax.shield_tick,
              color: AppColors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? "Update Role" : "Create Role",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEdit
                      ? "Modify the role's details and access permissions"
                      : "Define a role and configure its access permissions",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: AppColors.grey200, thickness: 1),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(BoxConstraints constraints) {
    final double currentWidth = constraints.maxWidth;
    const double horizontalSpacing = 16.0;
    const double verticalSpacing = 8.0;

    const double minColumnWidth = 220.0;

    final bool canShowGrid =
        currentWidth >= (minColumnWidth * 2 + horizontalSpacing);

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing) / 2
        : currentWidth;

    return Form(
      key: _formKey,
      child: Wrap(
        spacing: horizontalSpacing,
        runSpacing: verticalSpacing,
        children: [
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Role Name',
              controller: _roleNameController,
              hintText: 'Enter Role Name',
              isRequired: true,
              prefixIcon: const Icon(Iconsax.shield, size: 18),
              valid: (val) =>
                  val == null || val.isEmpty ? 'Role name is required' : null,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Description',
              controller: _descriptionController,
              hintText: 'Enter Description',
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        final duplicateError = await RoleService.checkRoleNameExists(
          name: _roleNameController.text.trim(),
        );
        if (duplicateError != null) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          FlushBar.show(context, duplicateError, isSuccess: false);
          return;
        }

        var reducedRows = _rows
            .where(
              (row) =>
                  row.canView ||
                  row.canCreate ||
                  row.canEdit ||
                  row.canDelete ||
                  row.canExport ||
                  row.canImport,
            )
            .toList();
        RoleModel roleModel = RoleModel(
          name: _roleNameController.text.trim(),
          description: _descriptionController.text.trim(),
          permissions: reducedRows,
          createdBy: await Spdb.getUser(),
        );

        await RoleService.createRole(role: roleModel);
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(context, 'Role created successfully', isSuccess: true);
      } catch (e, st) {
        await ErrorService.recordError(e, st);
        debugPrint("${e.toString()}, ${st.toString()}");
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        FlushBar.show(
          context,
          e.toString(),
          isSuccess: false,
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}