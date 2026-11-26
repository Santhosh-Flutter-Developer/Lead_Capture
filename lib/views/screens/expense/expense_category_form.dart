import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';

/// Create / edit an Expense Category. Pass [category] to edit.
/// Pops `{'status': true, 'name': <name>}` after a successful save.
class ExpenseCategoryForm extends StatefulWidget {
  final ExpenseCategoryModel? category;
  const ExpenseCategoryForm({super.key, this.category});

  @override
  State<ExpenseCategoryForm> createState() => _ExpenseCategoryFormState();
}

class _ExpenseCategoryFormState extends State<ExpenseCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  Color _color = const Color(0xFF2563EB);

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _name.text = c.name;
      _desc.text = c.description;
      _color = c.color;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      futureLoading(context);
      final name = _name.text.trim();
      final dup = await ExpenseCategoryService.checkExists(
        name: name,
        excludeUid: widget.category?.uid,
      );
      if (dup != null) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        if (mounted) FlushBar.show(context, dup, isSuccess: false);
        return;
      }
      final model = ExpenseCategoryModel(
        uid: widget.category?.uid,
        name: name,
        description: _desc.text.trim(),
        color: _color,
        createdBy: await Spdb.getUser(),
      );
      if (_isEdit) {
        await ExpenseCategoryService.update(widget.category!.uid ?? '', model);
      } else {
        await ExpenseCategoryService.create(model);
      }
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {'status': true, 'name': name});
      FlushBar.show(
        context,
        _isEdit ? 'Expense category updated successfully' : 'Expense category added successfully',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false, error: e, stackTrace: st);
    }
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
            LeadFormUI.header(
              context,
              title: _isEdit ? 'Edit Expense Category' : 'Add Expense Category',
              subtitle: 'Organize company expenses and financial tracking',
              icon: Iconsax.category,
            ),
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: LeadFormUI.sectionCard(
                      context,
                      title: 'Category Details',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormFields(
                            label: 'Category Name',
                            controller: _name,
                            hintText: 'e.g. Travel, Rent, Fuel',
                            isRequired: true,
                            prefixIcon: const Icon(Iconsax.tag, size: 18),
                            valid: (v) =>
                                (v == null || v.trim().isEmpty) ? '* Category name is required' : null,
                          ),
                          const SizedBox(height: 8),
                          FormFields(
                            label: 'Description',
                            controller: _desc,
                            hintText: 'Description (optional)',
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                            prefixIcon: const Icon(Iconsax.document_text, size: 18),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Colour',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () async {
                              final c = await pickColor(context, _color);
                              if (c != null) setState(() => _color = c);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ApiMappers.colorToServer(_color.toARGB32()),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  const Icon(Icons.palette_outlined, size: 18),
                                ],
                              ),
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
        bottomNavigationBar: LeadFormUI.bottomBar(context, onSubmit: _submit, isEdit: _isEdit),
      ),
    );
  }
}