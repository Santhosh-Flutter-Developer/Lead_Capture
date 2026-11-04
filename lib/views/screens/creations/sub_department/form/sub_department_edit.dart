import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class SubDepartmentEdit extends StatefulWidget {
  final String uid;
  const SubDepartmentEdit({super.key, required this.uid});

  @override
  State<SubDepartmentEdit> createState() => _SubDepartmentEditState();
}

class _SubDepartmentEditState extends State<SubDepartmentEdit> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
final ScrollController _scrollController = ScrollController();
  SubDepartmentModel? _subDepartmentModel;
  DepartmentModel? _selectedDepartment;
  late Future _future;

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    _subDepartmentModel = await SubDepartmentService.getSubDepartment(
      uid: widget.uid,
    );

    _nameController.text = _subDepartmentModel?.name ?? '';
    _descriptionController.text = _subDepartmentModel?.description ?? '';

    _selectedDepartment = await DepartmentService.getDepartment(
      uid: _subDepartmentModel?.department ?? '',
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const WaitingLoading();
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child:Padding(
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
                        child: _sectionCard(
                          context,
                          icon: Iconsax.info_circle,
                          title: "Sub Department Information",
                          subtitle:
                              "Link this sub department to its parent department",
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildFormFields(constraints),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: FormWidgets.buildBottomBar(
          context: context,
          onSubmit: _submitForm,
          isEdit: true,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            child: const Icon(Iconsax.edit, color: AppColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Sub Department",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Modify the sub department's details",
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
        currentWidth >= (minColumnWidth * 3 + horizontalSpacing * (3 - 1));

    final double itemWidth = canShowGrid
        ? (currentWidth - horizontalSpacing * (3 - 1)) / 3
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
              label: 'Sub Department Name',
              controller: _nameController,
              hintText: 'Enter sub department name',
              isRequired: true,
              prefixIcon: const Icon(Iconsax.building, size: 18),
              valid: (input) => input == null || input.isEmpty
                  ? 'Sub Department Name is required'
                  : null,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: CustomFutureSearchableDropdown<DepartmentModel>(
              label: 'Department',
              isRequired: true,
              validator: (_) {
                if (_selectedDepartment == null) {
                  return 'Department is required';
                }
                return null;
              },
              initialValue: _selectedDepartment,
              asyncItems: () async {
                var departments = await DepartmentService.getAllDepartments();
                return departments;
              },
              itemAsString: (departments) => departments.name,
              onChanged: (selectedDep) {
                setState(() {
                  _selectedDepartment = selectedDep;
                });
              },
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: FormFields(
              label: 'Description',
              controller: _descriptionController,
              hintText: 'Enter description (optional)',
              maxLines: 4,
              keyboardType: TextInputType.multiline,
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

        String? duplicateError = await SubDepartmentService.checkSubDepartmentExists(
          name: _nameController.text.trim(),
          excludeUid: widget.uid,
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(
            context,
            duplicateError,
            isSuccess: false,
          );
          return;
        }

        final subDepartmentModel = SubDepartmentModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          department: _selectedDepartment?.uid ?? '',
          createdBy: await Spdb.getUser(),
        );

        await SubDepartmentService.editSubDepartment(
          uid: widget.uid,
          subDepartment: subDepartmentModel,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(
          context,
          'Sub Department updated successfully',
          isSuccess: true,
        );
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