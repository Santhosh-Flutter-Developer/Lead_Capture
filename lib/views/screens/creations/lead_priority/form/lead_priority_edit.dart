import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/utils.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

class LeadPriorityEdit extends StatefulWidget {
  final String uid;
  const LeadPriorityEdit({super.key, required this.uid});

  @override
  State<LeadPriorityEdit> createState() => _LeadPriorityEditState();
}

class _LeadPriorityEditState extends State<LeadPriorityEdit> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _vScrollController = ScrollController();
  Color? _selectedColor;

  late Future _future;
  LeadPriorityModel? _leadPriorityModel;

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  @override
  void initState() {
    _future = _init();
    super.initState();
  }

  Future<void> _init() async {
    _leadPriorityModel = await LeadPriorityService.getLeadPriority(
      uid: widget.uid,
    );
    _nameController.text = _leadPriorityModel?.name ?? '';
    _descriptionController.text = _leadPriorityModel?.description ?? '';
    _selectedColor = _leadPriorityModel != null
        ? Color(_leadPriorityModel!.color)
        : null;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient,
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
                  "Update Lead Priority",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Update this priority's name, color and description",
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

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color? accentColor,
  }) {
    final Color badgeColor = accentColor ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
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
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: badgeColor),
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
            _buildHeader(context),
            Expanded(
              child: FutureBuilder(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const WaitingLoading();
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Scrollbar(
                    controller: _vScrollController,
                    thumbVisibility: true,
                    interactive: true,
                    trackVisibility: true,
                    radius: const Radius.circular(8),
                    thickness: 8,
                    child: SingleChildScrollView(
                          controller: _vScrollController,
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: _buildSectionCard(
                              icon: Iconsax.flag,
                              title: "Priority Information",
                              subtitle:
                                  "Give this priority a name, color and description",
                              child: LayoutBuilder(
                                builder: (context, constraints) =>
                                    _buildFormFields(constraints),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: "Update",
          icon: Iconsax.edit,
          onSubmit: _submitForm,
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required String label,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Cancel",
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _brandGradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4364F7).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSubmit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

    return Wrap(
      spacing: horizontalSpacing,
      runSpacing: verticalSpacing,
      children: [
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Priority Name',
            controller: _nameController,
            hintText: 'Enter Priority name',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.flag, size: 18),
            valid: (input) => input == null || input.isEmpty
                ? 'Priority Name is required'
                : null,
          ),
        ),
        SizedBox(width: itemWidth, child: _buildColorPicker()),
        SizedBox(
          width: currentWidth,
          child: FormFields(
            label: 'Description',
            controller: _descriptionController,
            hintText: 'Enter description (optional)',
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            prefixIcon: const Icon(Iconsax.document_text, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Color",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await pickColor(
                context,
                _selectedColor ?? Theme.of(context).colorScheme.primary,
              );
              if (picked != null) {
                setState(() => _selectedColor = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _selectedColor ?? AppColors.grey200,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedColor == null
                        ? "Tap to choose a color"
                        : "Color selected",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _selectedColor == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        futureLoading(context);

        String? duplicateError =
            await LeadPriorityService.checkLeadPriorityExists(
          name: _nameController.text.trim(),
          excludeUid: widget.uid,
        );

        if (duplicateError != null) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          FlushBar.show(context, duplicateError, isSuccess: false);
          return;
        }

        LeadPriorityModel leadPriorityModel = LeadPriorityModel(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          color: (_selectedColor ?? Theme.of(context).colorScheme.primary)
              .toARGB32(),
          createdBy: await Spdb.getUser(),
        );

        await LeadPriorityService.editLeadPriority(
          uid: widget.uid,
          leadPriority: leadPriorityModel,
        );

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.pop(context, true);

        FlushBar.show(
          context,
          'Priority updated successfully',
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