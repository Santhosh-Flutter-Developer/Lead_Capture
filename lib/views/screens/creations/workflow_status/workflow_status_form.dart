import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '/utils/utils.dart';
import '/services/services.dart';
import '/theme/theme.dart';
import '/views/views.dart';

/// Create / Edit form for Task Status and Ticket Status. Same layout as the
/// Lead Status / Deal Status create-edit forms (gradient header, section card,
/// Cancel / Save bottom bar), opened through GeneralDialog / Sheet.
class WorkflowStatusForm extends StatefulWidget {
  final WorkflowStatusService service;

  /// null => create, otherwise edit.
  final WorkflowStatus? status;
  const WorkflowStatusForm({super.key, required this.service, this.status});

  @override
  State<WorkflowStatusForm> createState() => _WorkflowStatusFormState();
}

class _WorkflowStatusFormState extends State<WorkflowStatusForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  Color _selectedColor = const Color(0xFF64748B);
  bool _isFinal = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _vScrollController = ScrollController();

  static const List<Color> _brandGradient = [
    Color(0xFF0052D4),
    Color(0xFF4364F7),
    Color(0xFF6FB1FC),
  ];

  bool get _isEdit => widget.status != null;
  bool get _isTicket => widget.service.isTicket;
  String get _label => widget.service.label; // Task Status / Ticket Status
  String get _noun => _isTicket ? 'ticket' : 'task';

  @override
  void initState() {
    super.initState();
    final s = widget.status;
    if (s != null) {
      _nameController.text = s.name;
      _keyController.text = s.statusKey;
      _orderController.text = '${s.orderIndex}';
      _descriptionController.text = s.description;
      _selectedColor = Color(s.color);
      _isFinal = s.isFinal;
    } else {
      _loadNextOrder();
    }
  }

  /// Order index defaults to the next free number (6 for tasks / 7 for tickets
  /// on a fresh install).
  Future<void> _loadNextOrder() async {
    try {
      final n = await widget.service.nextOrder();
      if (mounted && _orderController.text.isEmpty) {
        _orderController.text = '$n';
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _orderController.dispose();
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
            child: Icon(
              _isTicket ? Iconsax.ticket : Iconsax.task,
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
                  _isEdit ? "Edit $_label" : "Create $_label",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? "Update this stage of your ${_noun}s"
                      : "Add a new stage to track your ${_noun}s through",
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
  }) {
    final Color badgeColor = Theme.of(context).colorScheme.primary;
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
          children: [
            _buildHeader(context),
            Expanded(
              child: Padding(
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
                        icon: _isTicket ? Iconsax.ticket : Iconsax.task,
                        title: "Status Information",
                        subtitle:
                            "Give this status a name, key, color and description",
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildFormFields(constraints),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(
          label: _isEdit ? "Update" : "Create",
          icon: _isEdit ? Iconsax.edit : Iconsax.add,
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
            label: 'Status Name',
            controller: _nameController,
            hintText: 'Enter Status name',
            isRequired: true,
            prefixIcon: const Icon(Iconsax.status_up, size: 18),
            valid: (input) => input == null || input.trim().isEmpty
                ? 'Status Name is required'
                : null,
          ),
        ),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'System Key (Code)',
            controller: _keyController,
            hintText: 'Auto-generated from the name if empty',
            prefixIcon: const Icon(Iconsax.code, size: 18),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
            ],
          ),
        ),
        SizedBox(width: itemWidth, child: _buildColorPicker()),
        SizedBox(
          width: itemWidth,
          child: FormFields(
            label: 'Order Index',
            controller: _orderController,
            hintText: 'Lower numbers appear first',
            isRequired: true,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Iconsax.arrange_circle, size: 18),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            valid: (input) => input == null || input.trim().isEmpty
                ? 'Order Index is required'
                : null,
          ),
        ),
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
        SizedBox(width: currentWidth, child: _buildFinalToggle()),
      ],
    );
  }

  Widget _buildColorPicker() {
    final hex =
        '#${(_selectedColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
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
              final picked = await pickColor(context, _selectedColor);
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
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    hex,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildFinalToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isFinal
            ? AppColors.success.withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isFinal
              ? AppColors.success.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.tick_circle,
            size: 18,
            color: _isFinal
                ? AppColors.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTicket
                      ? 'Mark as Resolved / Closed Status'
                      : 'Mark as Completed Status',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isTicket
                      ? 'Tickets moved to this status are treated as closed.'
                      : 'Tasks moved to this status are treated as completed.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: _isFinal, onChanged: (v) => setState(() => _isFinal = v)),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      futureLoading(context);
      final order = int.tryParse(_orderController.text.trim()) ?? 0;
      if (_isEdit) {
        await widget.service.update(
          uid: widget.status!.uid,
          name: _nameController.text,
          statusKey: _keyController.text,
          description: _descriptionController.text,
          color: _selectedColor.toARGB32(),
          orderIndex: order,
          isFinal: _isFinal,
        );
      } else {
        await widget.service.create(
          name: _nameController.text,
          statusKey: _keyController.text,
          description: _descriptionController.text,
          color: _selectedColor.toARGB32(),
          orderIndex: order,
          isFinal: _isFinal,
        );
      }
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loading
      Navigator.pop(context, {
        "status": true,
        "name": _nameController.text.trim(),
      });
      FlushBar.show(
        context,
        _isEdit ? 'Status updated successfully' : 'Status created successfully',
        isSuccess: true,
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      debugPrint("${e.toString()}, ${st.toString()}");
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loading
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