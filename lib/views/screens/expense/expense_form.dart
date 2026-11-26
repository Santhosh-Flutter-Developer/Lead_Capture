import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import '/constants/constants.dart';
import '/models/models.dart';
import '/services/services.dart';
import '/utils/utils.dart';
import '/views/views.dart';
import '/views/screens/leads/form/lead_form_ui.dart';
import 'expense_category_form.dart';

/// Add / edit an expense. Pass [uid] to edit.
/// Pops `{'status': true}` after a successful save.
class ExpenseForm extends StatefulWidget {
  final String? uid;
  const ExpenseForm({super.key, this.uid});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _dateC = TextEditingController();
  final _amountC = TextEditingController();
  final _upiC = TextEditingController();
  final _descC = TextEditingController();

  List<MasterCompanyModel> _companies = [];
  List<ExpenseCategoryModel> _categories = [];
  List<String> _modes = [];
  MasterCompanyModel? _company;
  ExpenseCategoryModel? _category;
  String _mode = '';
  DateTime _date = DateTime.now();

  /// Attachments already stored on the expense (sent back untouched).
  final List<Map<String, dynamic>> _existing = [];
  final List<PlatformFile> _newFiles = [];

  bool _loading = true;
  String? _error;
  int _tick = 0;
  bool _canAddCategory = false;
  bool _canAddCompany = false;

  bool get _isEdit => widget.uid != null;
  bool get _isUpi => _mode.trim().toLowerCase() == 'upi';

  @override
  void initState() {
    super.initState();
    _dateC.text = DateFormat('dd-MM-yyyy').format(_date);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _dateC.dispose();
    _amountC.dispose();
    _upiC.dispose();
    _descC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([
        MasterCompanyService.getAll(),
        ExpenseCategoryService.getAll(),
        PaymentModeService.getAllPaymentMode(),
        PermissionService.getPermissions('Expense Category'),
        PermissionService.getPermissions('Our Company'),
      ]);
      _companies = res[0] as List<MasterCompanyModel>;
      _categories = res[1] as List<ExpenseCategoryModel>;
      _modes = (res[2] as List<PaymentModeModel>).map((m) => m.name).toList();
      _canAddCategory = (res[3] as PermissionModel?)?.canCreate ?? false;
      _canAddCompany = (res[4] as PermissionModel?)?.canCreate ?? false;

      if (_isEdit) {
        final e = await ExpenseService.get(uid: widget.uid!);
        _company = _companies.where((c) => c.uid == e.masterCompanyId).firstOrNull;
        _category = _categories.where((c) => c.uid == e.categoryId).firstOrNull;
        _mode = e.paymentMode;
        _date = e.expenseDate;
        _dateC.text = DateFormat('dd-MM-yyyy').format(_date);
        _amountC.text = e.amount == e.amount.roundToDouble()
            ? e.amount.toStringAsFixed(0)
            : e.amount.toString();
        _upiC.text = e.upiNumber;
        _descC.text = e.description;
        _existing
          ..clear()
          ..addAll(e.rawAttachments);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<dynamic> _openSheet(Widget form) {
    if (kIsMobile) return Sheet.showSheet(context, widget: form);
    return GeneralDialog.showRTLSheet(context, form);
  }

  Widget _plusButton(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }

  FileModel _fileFromRaw(Map<String, dynamic> m) => CrmMappers.file(m);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      futureLoading(context);
      final attachments = <Map<String, dynamic>>[..._existing];
      if (_newFiles.isNotEmpty) {
        final data = await Future.wait(
          _newFiles.map((pf) async {
            final bytes = await platformFileToBytes(pf);
            return (bytes: bytes, fileName: pf.name);
          }),
        );
        final urls = await StorageService.uploadBytesInBatch(
          files: data,
          folder: StorageFolder.expenseAttachments,
        );
        for (var i = 0; i < _newFiles.length; i++) {
          final pf = _newFiles[i];
          final rel = ApiConfig.toRelativePath(urls[i]);
          attachments.add({
            'id': ApiAttachments.idOf(urls[i]),
            'file_name': pf.name,
            'file_url': rel,
            'file_path': rel,
            'file_size': pf.size,
            'file_extension': pf.extension ?? '',
            'file_type': lookupMimeType(pf.name) ?? '',
          });
        }
      }
      await ExpenseService.save(
        uid: widget.uid,
        masterCompanyId: _company!.uid ?? '',
        categoryId: _category!.uid ?? '',
        amount: double.parse(_amountC.text.trim()),
        paymentMode: _mode,
        upiNumber: _isUpi ? _upiC.text.trim() : '',
        expenseDate: _date,
        description: _descC.text.trim(),
        attachments: attachments,
      );
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // loader
      Navigator.pop(context, {'status': true});
      FlushBar.show(
        context,
        _isEdit ? 'Expense updated successfully' : 'Expense created successfully',
      );
    } catch (e, st) {
      await ErrorService.recordError(e, st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      FlushBar.show(context, e.toString(), isSuccess: false, error: e, stackTrace: st);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _row(BuildContext context, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 420;
        if (!wide) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final fieldGap = const SizedBox(height: 8);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadFormUI.sectionCard(
            context,
            title: 'Entity & Classification',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FormDropdownSearch(
                        key: ValueKey('comp_${_companies.length}_${_company?.uid}_$_tick'),
                        label: 'Our Company',
                        isRequired: true,
                        initialItem: _company?.companyName,
                        items: _companies.map((c) => c.companyName).toList(),
                        onChanged: (v) =>
                            _company = _companies.where((c) => c.companyName == v).firstOrNull,
                        validator: (v) => v == null ? '* Our company is required' : null,
                      ),
                    ),
                    if (_canAddCompany) ...[
                      const SizedBox(width: 8),
                      _plusButton(() async {
                        final val = await _openSheet(const MasterCompanyForm());
                        if (val is Map && val['status'] == true) {
                          _companies = await MasterCompanyService.getAll();
                          if (val['company'] is MasterCompanyModel) {
                            _company = val['company'] as MasterCompanyModel;
                          }
                          if (mounted) setState(() => _tick++);
                        }
                      }),
                    ],
                  ],
                ),
                fieldGap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FormDropdownSearch(
                        key: ValueKey('cat_${_categories.length}_${_category?.uid}_$_tick'),
                        label: 'Expense Category',
                        isRequired: true,
                        initialItem: _category?.name,
                        items: _categories.map((c) => c.name).toList(),
                        onChanged: (v) =>
                            _category = _categories.where((c) => c.name == v).firstOrNull,
                        validator: (v) => v == null ? '* Expense category is required' : null,
                      ),
                    ),
                    if (_canAddCategory) ...[
                      const SizedBox(width: 8),
                      _plusButton(() async {
                        final val = await _openSheet(const ExpenseCategoryForm());
                        if (val is Map && val['status'] == true) {
                          _categories = await ExpenseCategoryService.getAll();
                          _category = _categories
                              .where((c) => c.name == val['name'])
                              .firstOrNull;
                          if (mounted) setState(() => _tick++);
                        }
                      }),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LeadFormUI.sectionCard(
            context,
            title: 'Payment & Value',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(context, [
                  FormFields(
                    label: 'Expense Date',
                    controller: _dateC,
                    isRequired: true,
                    readOnly: true,
                    suffixIcon: const Icon(Iconsax.calendar_1, size: 18),
                    valid: (v) => (v == null || v.isEmpty) ? '* Expense date is required' : null,
                    onTap: () async {
                      final p = await pickDate(context, initialDate: _date);
                      if (p != null) {
                        _date = DateFormat('dd-MM-yyyy').parse(p);
                        _dateC.text = p;
                        setState(() {});
                      }
                    },
                  ),
                  FormFields(
                    label: 'Amount',
                    controller: _amountC,
                    hintText: 'Enter amount',
                    isRequired: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    valid: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if ((v ?? '').trim().isEmpty) return '* Amount is required';
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ]),
                fieldGap,
                FormDropdownSearch(
                  key: ValueKey('mode_${_modes.length}_$_tick'),
                  label: 'Payment Mode',
                  isRequired: true,
                  initialItem: _mode.isEmpty ? null : _mode,
                  items: [
                    ..._modes,
                    if (_mode.isNotEmpty && !_modes.contains(_mode)) _mode,
                  ],
                  onChanged: (v) => setState(() {
                    _mode = (v as String?) ?? '';
                    if (!_isUpi) _upiC.clear();
                  }),
                  validator: (v) => v == null ? '* Payment mode is required' : null,
                ),
                if (_isUpi) ...[
                  fieldGap,
                  FormFields(
                    label: 'UPI Number',
                    controller: _upiC,
                    hintText: 'Enter UPI number / ID',
                    isRequired: true,
                    valid: (v) =>
                        (v == null || v.trim().isEmpty) ? '* UPI number is required' : null,
                  ),
                ],
                fieldGap,
                FormFields(
                  label: 'Description',
                  controller: _descC,
                  hintText: 'Enter expense notes or purpose...',
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LeadFormUI.sectionCard(
            context,
            title: 'Bill & Receipt Attachments',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final files = await FilePick.pickFiles(context);
                    if (files != null && files.isNotEmpty) {
                      _newFiles.addAll(files);
                      setState(() {});
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Iconsax.document_upload,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Click to upload bill copies / receipts',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Images, PDF or receipt scans',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_existing.isNotEmpty || _newFiles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final raw in _existing)
                        AttachmentPill(
                          name: _fileFromRaw(raw).name,
                          onOpen: () => previewAttachment(context, _fileFromRaw(raw)),
                          onRemove: () => setState(() => _existing.remove(raw)),
                        ),
                      for (final f in _newFiles)
                        AttachmentPill(
                          name: f.name,
                          onRemove: () => setState(() => _newFiles.remove(f)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
            LeadFormUI.header(
              context,
              title: _isEdit ? 'Edit Expense' : 'Add Expense',
              subtitle: 'Record company expenditure and attach bills',
              icon: Iconsax.wallet_3,
            ),
            Expanded(
              child: _loading
                  ? const WaitingLoading()
                  : _error != null
                      ? Center(child: Text(_error!))
                      : Scrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(18),
                            child: _body(context),
                          ),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: _loading || _error != null
            ? null
            : LeadFormUI.bottomBar(context, onSubmit: _submit, isEdit: _isEdit),
      ),
    );
  }
}